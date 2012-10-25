package ru.inspirit.fft 
{
	import apparat.asm.__asm;
	import apparat.asm.__cint;
	import apparat.asm.DecLocalInt;
	import apparat.asm.IncLocalInt;
	import apparat.inline.Macro;
	import apparat.memory.Memory;
	
	/**
	 * FFT help routines
	 * @author Eugene Zatepyakin
	 */
	public final class FFTMacro extends Macro 
	{
		/**
		 * Radix-4 FFT butterfly
		 * transforms input inplace
		 * @param	in_re		real component
		 * @param	in_im		imag component
		 * @param	n			input length (power of 2)
		 * @param	l2n			log2 of input length
		 * @param	lut_ptr		mem offset to sin/cos lut table
		 */
		public static function doFFTR4(in_re:int, in_im:int, n:int, l2n:int, lut_ptr:int):void
		{
			var tmp0_re:Number, tmp0_im:Number, tmp1_re:Number, tmp1_im:Number;
			var tmp2_re:Number, tmp2_im:Number, tmp3_re:Number, tmp3_im:Number;
			var tmp00_re:Number, tmp00_im:Number, tmp01_re:Number, tmp01_im:Number;
			var tmp02_re:Number, tmp02_im:Number, tmp03_re:Number, tmp03_im:Number;
			var out0_re:Number, out0_im:Number, out1_re:Number, out1_im:Number;
			var out2_re:Number, out2_im:Number, out3_re:Number, out3_im:Number;
			var i:int, j:int;
			var off:int, off0:int;
			var iL:int, iB:int, le:int;
			var cs:Number, sn:Number;
			var iB8:int;
			
			var lp:int = lut_ptr;
			var d0:int = __cint(in_re - in_im);
			
			for (iL = 1; iL <= l2n; )
			{
				le = (1 << (iL << 1));
				iB = le >> 2; // Distance of the butterfly
				iB8 = iB << 3;
				for (j = 0; j < iB; )
				{
					// get sin/cos from lut table
					tmp1_re = Memory.readDouble(lp);
					tmp1_im = Memory.readDouble(__cint(lp+8));
					tmp2_re = Memory.readDouble(__cint(lp+16));
					tmp2_im = Memory.readDouble(__cint(lp+24));
					tmp3_re = Memory.readDouble(__cint(lp+32));
					tmp3_im = Memory.readDouble(__cint(lp+40));
					lp = __cint(lp + 48);
					
					for (i = j; i < n; )
					{
						off0 = off = __cint((i << 3) + in_re);
						
						var re0:Number = Memory.readDouble(off);
						var im0:Number = Memory.readDouble(__cint(off - d0));
						off = __cint(off + iB8);
						var re1:Number = Memory.readDouble(off);
						var im1:Number = Memory.readDouble(__cint(off - d0));
						off = __cint(off + iB8);
						var re2:Number = Memory.readDouble(off);
						var im2:Number = Memory.readDouble(__cint(off - d0));
						off = __cint(off + iB8);
						var re3:Number = Memory.readDouble(off);
						var im3:Number = Memory.readDouble(__cint(off - d0));
						
						// multiply
						// skip first input since it is unchanged 
						out1_re = re1 * tmp1_re - im1 * tmp1_im;
						out1_im = re1 * tmp1_im + im1 * tmp1_re;
						
						out2_re = re2 * tmp2_re - im2 * tmp2_im;
						out2_im = re2 * tmp2_im + im2 * tmp2_re;
						
						out3_re = re3 * tmp3_re - im3 * tmp3_im;
						out3_im = re3 * tmp3_im + im3 * tmp3_re;
						
						tmp00_re = re0 + out1_re;
						tmp00_im = im0 + out1_im;
						
						tmp01_re = re0 - out1_re;
						tmp01_im = im0 - out1_im;
						
						tmp02_re = out2_re + out3_re;
						tmp02_im = out2_im + out3_im;
						
						tmp03_re = out2_im - out3_im;
						tmp03_im = out3_re - out2_re;
						
						
						// write result back
						// avoid unneeded get/set local vars
						Memory.writeDouble(tmp00_re + tmp02_re, off0);
						Memory.writeDouble(tmp00_im + tmp02_im, __cint(off0 - d0));
						off0 = __cint(off0 + iB8);
						Memory.writeDouble(tmp01_re + tmp03_re, off0);
						Memory.writeDouble(tmp01_im + tmp03_im, __cint(off0 - d0));
						off0 = __cint(off0 + iB8);
						Memory.writeDouble(tmp00_re - tmp02_re, off0);
						Memory.writeDouble(tmp00_im - tmp02_im, __cint(off0 - d0));
						off0 = __cint(off0 + iB8);
						Memory.writeDouble(tmp01_re - tmp03_re, off0);
						Memory.writeDouble(tmp01_im - tmp03_im, __cint(off0 - d0));
						
						//
						i = __cint(i + le);
					}
					//
					__asm(IncLocalInt(j));
				}
				//
				__asm(IncLocalInt(iL));
			}
		}
		
		/**
		 * Radix-2 FFT butterfly
		 * transforms input inplace
		 * @param	in_re		real component
		 * @param	in_im		imag component
		 * @param	n			input length (power of 2)
		 * @param	lut_ptr		mem offset to sin/cos lut table
		 */
		public static function doFFTL2(in_re:int, in_im:int, n:int, lut_ptr:int):void
		{
			var tmp0_re:Number, tmp0_im:Number;
			var out1_re:Number, out1_im:Number;
			var re0:Number, im0:Number, re1:Number, im1:Number;
			var off:int;
			var iB:int = n >> 1;
			var iB8:int = iB << 3;
			
			var lp:int = lut_ptr;
			var d0:int = __cint(in_re - in_im);
			var re_ptr:int = in_re;
			
			for (var i:int = 0; i < iB; )
			{
				tmp0_re = Memory.readDouble(lp);
				tmp0_im = Memory.readDouble(__cint(lp + 8));
				lp = __cint(lp + 16);
				//
				// read input
				off = __cint(iB8 + re_ptr);
				re0 = Memory.readDouble(re_ptr);
				im0 = Memory.readDouble(__cint(re_ptr - d0));
				
				re1 = Memory.readDouble(off);
				im1 = Memory.readDouble(__cint(off - d0));
				
				// mult
				// skip first input since it is unchanged 
				out1_re = re1 * tmp0_re - im1 * tmp0_im;
				out1_im = re1 * tmp0_im + im1 * tmp0_re;
				
				// avoid unneeded get/set local vars
				Memory.writeDouble(re0 + out1_re, re_ptr);
				Memory.writeDouble(im0 + out1_im, __cint(re_ptr - d0));
				
				Memory.writeDouble(re0 - out1_re, off);
				Memory.writeDouble(im0 - out1_im, __cint(off - d0));
				//
				__asm(IncLocalInt(i));
				re_ptr = __cint(re_ptr + 8);
			}
		}
		
		/**
		 * Find out if input is power of 4
		 * 
		 * @param	n		input integer to check
		 * @param	result	result 1/0 == true/false
		 * @param	mem		memory offset to perform read/write operation
		 */
		public static function isPowerOf4(n:int, result:int, mem:int):void
		{
			var log2n:int;
			FFTMacro.log2(n, log2n, mem);
			result = int( __cint((n&(n-1)|(log2n&1))) == 0 );
		}
		
		/**
		 * Magic (MAGIC) integer Base 2 logarithm method by Patrick Leclech :)
		 * @param	n		input integer
		 * @param	log2n	result output
		 * @param	mem		memory offset to perform read/write operation
		 */
		public static function log2(n:int, log2n:int, mem:int):void
		{
			Memory.writeDouble(n, mem);
			log2n = __cint((Memory.readInt(mem+4) >> 20) - 1023);
		}
		
		// bit reverse data before transforming
		public static function bitReverse(re_ptr:int, im_ptr:int, bit_ptr:int, numBitRev:int):void
		{
			var d0:int = __cint(re_ptr - im_ptr);
			while (numBitRev > 0)
			{
				var ind1:int = __cint(Memory.readInt(bit_ptr) + re_ptr);
				var ind2:int = __cint(Memory.readInt(bit_ptr+4) + re_ptr);
				bit_ptr = __cint(bit_ptr + 8);
				
				var tx:Number = Memory.readDouble(ind1);
				var ty:Number = Memory.readDouble(__cint(ind1 - d0));
				Memory.writeDouble(Memory.readDouble(ind2), ind1);
				Memory.writeDouble(Memory.readDouble(__cint(ind2 - d0)), __cint(ind1 - d0));
				Memory.writeDouble(tx, ind2);
				Memory.writeDouble(ty, __cint(ind2 - d0));
				
				__asm(DecLocalInt(numBitRev));
			}
		}
		
	}

}