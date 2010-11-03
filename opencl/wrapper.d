/*
cl4d - object-oriented wrapper for the OpenCL C API v1.1
written in the D programming language

Copyright (C) 2009-2010 Andreas Hollandt

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/
module opencl.wrapper;

import opencl.error;
import opencl.c.cl;
import opencl.kernel;
import opencl.platform;
import opencl.device;

package
{
	alias const(char) cchar;
	alias const(wchar) cwchar;
	alias const(dchar) cdchar;
	alias immutable(char) ichar;
	alias immutable(wchar) iwchar;
	alias immutable(dchar) idchar;
	alias const(char)[] cstring;
}

// alternate Info getter functions
private alias extern(C) cl_int function(const(void)*, const(void*), cl_uint, size_t, void*, size_t*) Func;

/// abstract base class 
abstract class CLWrapper(T, alias infoFunction)
{
protected:
	T _object = null;

package:
	this() {}
	this(T obj)
	{
		_object = obj;
	}

	// should only be used inside here
	package T getObject()
	{
		return _object;
	}
	
	// used for all non-array types
	U getInfo(U)(cl_uint infoname, Func altFunction = null, cl_device_id device = null)
	{
		assert(_object !is null);
		size_t needed;
		cl_int res;
		
		// get amount of memory necessary
		if (altFunction != null && device != null)
			res = altFunction(_object, device, infoname, 0, null, &needed);
		else
			res = infoFunction(_object, infoname, 0, null, &needed);

		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		assert(needed == U.sizeof); // TODO:
		
		U info;

		// get actual data
		if (altFunction != null && device != null)
			res = altFunction(_object, device, infoname, U.sizeof, &info, null);
		else
			res = infoFunction(_object, infoname, U.sizeof, &info, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return info;
	}
	
	// helper function for all OpenCL Get*Info functions
	// used for all array return types
	U[] getArrayInfo(U)(cl_uint infoname, Func altFunction = null, cl_device_id device = null)
	{
		assert(_object !is null);
		size_t needed;
		cl_int res;

		// get number of needed memory
		if (altFunction != null && device != null)
			res = altFunction(_object, device, infoname, 0, null, &needed);
		else
			res = infoFunction(_object, infoname, 0, null, &needed);

		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		auto buffer = new U[needed];

		// get actual data
		if (altFunction != null && device != null)
			res = altFunction(_object, device, infoname, buffer.length, cast(void*)buffer.ptr, null);
		else
			res = infoFunction(_object, infoname, buffer.length, cast(void*)buffer.ptr, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return buffer;
	}
	
	string getStringInfo(cl_uint infoname, Func altFunction = null, cl_device_id device = null)
	{
		return cast(string) getArrayInfo!(char)(infoname, altFunction, device);
	}

	//	static cl_int getInfo(Arg0, Arg1)(Arg0 arg0, Arg1)

}

/**
 *	a collection of OpenCL objects returned by some methods
 */
class CLObjectCollection(T)
{
private:
	T[] _objects;

	static if(is(T == cl_platform_id))
		alias CLPlatform Wrapper;
	static if(is(T == cl_device_id))
		alias CLDevice Wrapper;
	static if(is(T == cl_kernel))
		alias CLKernel Wrapper;
	// TODO: rest of the types
	
public:
	/// takes a list of OpenCL objects returned by some OpenCL functions like GetPlatformIDs
	this(T[] objects)
	{
		_objects = objects;
		
		for(uint i=0; i<objects.length; i++)
		{
			// increment the reference counter so the object won't be destroyed
			// NOTE: nothing to do for platform and device
			
			static if(is(T == cl_context))
			{
				if (clRetainContext(objects[i]) != CL_SUCCESS)
					throw new CLInvalidContextException();
			}
			
			// TODO: other objects
		}
	}
	
	~this()
	{
		for(uint i=0; i<_objects.length; i++)
		{
			// increment the reference counter so the object won't be destroyed
			static if(is(T == cl_context))
			{
				if (clReleaseContext(_objects[i]) != CL_SUCCESS)
					throw new CLInvalidContextException();
			}
			
			// TODO: other objects
		}
	}
	
	/// used to internally get the underlying object pointers
	package T[] getObjArray()
	{
		return _objects;
	}
	
	/// returns a new instance wrapping object i
	Wrapper opIndex(size_t i)
	{
		return new Wrapper(_objects[i]);
	}
	
	/// for foreach to work
	int opApply(int delegate(ref Wrapper) dg)
	{
		int result = 0;
		
		for(uint i=0; i<_objects.length; i++)
		{
			Wrapper w = new Wrapper(_objects[i]);
			result = dg(w);
			if(result)
				break;
		}
		
		return result;
	}
}