package ru.inspirit.fft 
{
	import apparat.asm.__as3;
	import apparat.asm.__asm;
	import apparat.asm.__cint;
	import apparat.asm.CallProperty;
	import apparat.asm.DecLocalInt;
	import apparat.asm.IncLocalInt;
	import apparat.asm.SetLocal;
	import apparat.math.IntMath;
	import apparat.memory.Memory;
	
	/**
	 * Fast Fourier Transform (FFT)
	 * The class provides methods supporting the
	 * performance of in-place mixed-radix Fast Fourier Transforms.
	 * 
	 * @author Eugene Zatepyakin
	 */
	
	public final class FFT 
	{
		
		public var memPtr:int;
		
		protected var lutR4Ptr:int;
		protected var lutR2Ptr:int;
		protected var bitPtr:int;
		
		protected var numBitRev:int;
		
		protected var lastLength:int = -1; // last input length
		protected var lastP2Length:int = -1; // last power of 2 length
		protected var lastL2Length:int = -1; // last log2 length
		protected var lastInvP2Length:Number = -1;
		
		public function FFT() { }
		
		public function calcRequiredChunkSize(maxLength:int):int
        {
        	var size:int = 0;
			var l2:int = IntMath.nextPow2(maxLength);			
			
			size += (l2 * 4) << 3; // 2 lut tables radix 2/4
            size += l2 << 3; // bitrev table
			size += 8; // for magic log2 macro
        	
        	return IntMath.nextPow2(size);
        }
		
		public function setup(memOffset:int, maxLength:int):void
		{
			memPtr = memOffset;
			memOffset += 8; // for magic log2 macro
			
			var ptr:int = memPtr;
			var l2:int = IntMath.nextPow2(maxLength);
			
			lutR4Ptr = memOffset;
			memOffset += (l2 * 2) << 3; // lut table radix-4
			lutR2Ptr = memOffset;
			memOffset += (l2 * 2) << 3; // lut table radix-2
			
			bitPtr = memOffset;
			memOffset += l2 << 3; // bitrev table
			
			// invalidate
			lastInvP2Length = lastLength = lastL2Length = lastP2Length = -1;
		}
		
		// assume u run init() before it
		public function forward(re_ptr:int, im_ptr:int):void
		{
			var n:int = lastP2Length;
			var l2n:int = lastL2Length;
			var hl2n:int = l2n >> 1;
			var ind1:int, ind2:int;
			var isPow4:int;
			var lut_ptr:int;
			
			var i:int = numBitRev;
			var ptr:int = bitPtr;
			FFTMacro.bitReverse(re_ptr, im_ptr, ptr, i);
			
			ptr = memPtr;
			FFTMacro.isPowerOf4(n, isPow4, ptr);
			
			lut_ptr = lutR4Ptr;
			FFTMacro.doFFTR4(re_ptr, im_ptr, n, hl2n, lut_ptr);
			
			if (!isPow4) // if not power of 4
			{
				// the last stage is radix 2
				lut_ptr = lutR2Ptr;
				FFTMacro.doFFTL2(re_ptr, im_ptr, n, lut_ptr);
			}
		}
		
		public function inverse(re_ptr:int, im_ptr:int):void
		{
			var n:int = lastP2Length;
			var l2n:int = lastL2Length;
			var hl2n:int = l2n >> 1;
			var ind1:int, ind2:int, i:int, ptr:int;
			var isPow4:int;
			var lut_ptr:int;
			
			// conj input
			ptr = im_ptr;
			i = __cint(ptr + (n << 3));
			while (ptr < i)
			{
				Memory.writeDouble( -Memory.readDouble(ptr), ptr );
				ptr = __cint(ptr + 8);
			}
			
			// reverse bits
			i = numBitRev;
			ptr = bitPtr;
			FFTMacro.bitReverse(re_ptr, im_ptr, ptr, i);
			
			ptr = memPtr;
			FFTMacro.isPowerOf4(n, isPow4, ptr);
			
			lut_ptr = lutR4Ptr;
			FFTMacro.doFFTR4(re_ptr, im_ptr, n, hl2n, lut_ptr);
			
			if (!isPow4) // if not power of 4
			{
				// the last stage is radix 2
				lut_ptr = lutR2Ptr;
				FFTMacro.doFFTL2(re_ptr, im_ptr, n, lut_ptr);
			}
			
			// scale & conj data
			var invN:Number = lastInvP2Length;
			ptr = im_ptr;
			i = __cint(ptr + (n << 3));
			while (ptr < i)
			{
				Memory.writeDouble(  Memory.readDouble(re_ptr) * invN, re_ptr );
				Memory.writeDouble( -Memory.readDouble(ptr) * invN, ptr );
				ptr = __cint(ptr + 8);
				re_ptr = __cint(re_ptr + 8);
			}
		}
		
		public function init(length:int):void
		{
			var l2:int, l2n:int;
			var isPow4:int;
			var i:int;
			var forward:int, rev:int, zeros:int;
			var nodd:int, noddrev:int;
			var halfn:int, quartn:int, nmin1:int;
			var ptr:int;
			var math:*;
			
			if (lastLength != length)
			{
				l2 = IntMath.nextPow2(length);
				ptr = memPtr;
				FFTMacro.log2(l2, l2n, ptr);
				FFTMacro.isPowerOf4(l2, isPow4, ptr);
				
				// store new values
				lastLength = length;
				lastP2Length = l2;
				lastL2Length = l2n;
				
				var invL2:Number = lastInvP2Length = 1.0 / Number(l2);
				var hl2n:int = l2n >> 1;
				
				// create bit reverse table
				halfn = l2 >> 1;
				quartn = l2 >> 2;
				nmin1 = __cint(l2-1);
				forward = halfn;
				rev = 1;
				ptr = bitPtr;
				numBitRev = 0;
				for(i = quartn; i; )    // start of bitreversed permutation loop, N/4 iterations
				{
					// Gray code generator for even values:
					nodd = ~i;                                  // counting ones is easier
					for(zeros=0; nodd&1; zeros++) nodd >>= 1;   // find trailing zero's in i
					forward ^= 2 << zeros;                      // toggle one bit of forward
					rev ^= quartn >> zeros;                     // toggle one bit of rev
					//
					if(forward < rev)                          // swap even and ~even conditionally
					{
						// swap
						Memory.writeInt(forward<<3, ptr); ptr = __cint(ptr + 4);
						Memory.writeInt(rev<<3, ptr); ptr = __cint(ptr + 4);
						nodd = nmin1 ^ forward;              // compute the bitwise negations
						noddrev = nmin1 ^ rev;        
						// swap bitwise-negated pairs
						Memory.writeInt(nodd<<3, ptr); ptr = __cint(ptr + 4);
						Memory.writeInt(noddrev<<3, ptr); ptr = __cint(ptr + 4);
						
						numBitRev = __cint(numBitRev + 2);
					}
					nodd = forward ^ 1;                      // compute the odd values from the even
					noddrev = rev ^ halfn;
					// swap odd unconditionally
					Memory.writeInt(nodd<<3, ptr); ptr = __cint(ptr + 4);
					Memory.writeInt(noddrev<<3, ptr); ptr = __cint(ptr + 4);
					numBitRev = __cint(numBitRev + 1);
					//
					__asm(DecLocalInt(i));
				}
				
				// create sin/cos lut tables
				__asm(__as3(Math), SetLocal(math));
				
				var iB:int;
				var an:Number, cs:Number, sn:Number;
				
				// radix-4 lut table
				ptr = lutR4Ptr;
				for (var iL:int = 1; iL <= hl2n; )
				{
					var le:int = (1 << (iL << 1));
					var invLe:Number = 1.0 / Number(le);
					iB = le >> 2;
					for (i = 0; i < iB; )
					{
						var pi2:Number = (6.283185307179586 * invLe);
						
						an = pi2 * 2.0 * Number(i);
						__asm(__as3(math), __as3(an), CallProperty(__as3(Math.cos), 1), SetLocal(cs));
						__asm(__as3(math), __as3(an), CallProperty(__as3(Math.sin), 1), SetLocal(sn));
						//
						Memory.writeDouble(cs, ptr); ptr = __cint(ptr + 8);
						Memory.writeDouble(-sn, ptr); ptr = __cint(ptr + 8);
						//
						an = pi2 * Number(i);
						__asm(__as3(math), __as3(an), CallProperty(__as3(Math.cos), 1), SetLocal(cs));
						__asm(__as3(math), __as3(an), CallProperty(__as3(Math.sin), 1), SetLocal(sn));
						//
						Memory.writeDouble(cs, ptr); ptr = __cint(ptr + 8);
						Memory.writeDouble(-sn, ptr); ptr = __cint(ptr + 8);
						//
						an = pi2 * 3.0 * Number(i);
						__asm(__as3(math), __as3(an), CallProperty(__as3(Math.cos), 1), SetLocal(cs));
						__asm(__as3(math), __as3(an), CallProperty(__as3(Math.sin), 1), SetLocal(sn));
						//
						Memory.writeDouble(cs, ptr); ptr = __cint(ptr + 8);
						Memory.writeDouble(-sn, ptr); ptr = __cint(ptr + 8);
						//
						__asm(IncLocalInt(i));
					}
					//
					__asm(IncLocalInt(iL));
				}
				
				if (isPow4) return; // exit if input is power of 4
				
				// radix-2 lut table
				iB = l2 >> 1;
				ptr = lutR2Ptr;
				for (i = 0; i < iB; )
				{
					an = (6.283185307179586 * invL2) * Number(i);
					__asm(__as3(math), __as3(an), CallProperty(__as3(Math.cos), 1), SetLocal(cs));
					__asm(__as3(math), __as3(an), CallProperty(__as3(Math.sin), 1), SetLocal(sn));
					//
					Memory.writeDouble(cs, ptr); ptr = __cint(ptr + 8);
					Memory.writeDouble(-sn, ptr); ptr = __cint(ptr + 8);
					//
					__asm(IncLocalInt(i));
				}
				
				//throw new Error('fft init: ' + [numBitRev, l2, l2n]);
			}
		}
		
	}

}