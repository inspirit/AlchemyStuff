package ru.inspirit.image 
{
	import apparat.asm.__as3;
	import apparat.asm.__asm;
	import apparat.asm.__cint;
	import apparat.asm.CallProperty;
	import apparat.asm.SetLocal;
	import apparat.math.FastMath;
	import apparat.math.IntMath;
	import apparat.memory.Memory;
	import ru.inspirit.fft.FFT;

    /**
	 * TEMPLATE MATCHING is a cpu efficient function which calculates matching
     * scores between template and image. (grayscale only)
     * Measures are implemented using FFT based correlation.
     *
	 * @author Eugene Zatepyakin
	 */
	public final class TemplateMatchFFT
	{
		public static const CCORR:int = 0;
		public static const CCORR_NORMED:int = 1;
		public static const CCOEFF:int = 2;
		public static const CCOEFF_NORMED:int = 3;
		public static const SQDIFF:int = 4;
		public static const SQDIFF_NORMED:int = 5;
		
		public var memPtr:int;
		
		protected var re_inPtr:int;
		protected var im_inPtr:int;
		protected var reTemplPtr:int;
		protected var imTemplPtr:int;
		protected var reImgPtr:int;
		protected var imImgPtr:int;

		protected var intSPtr:int;
		protected var intSQPtr:int;
		
		protected var templMean:Number;
		protected var templSdv:Number;
		
		protected const fft:FFT = new FFT();

		public function calcRequiredChunkSize(width:int, height:int):int
        {
        	var size:int = 0;
			var w2:int = IntMath.nextPow2(width);
			var h2:int = IntMath.nextPow2(height);
			var ms:int = IntMath.max(w2, h2);
			var area2:int = __cint(ms * ms);
			size += (area2 * 6) << 3; // re/im & in/out
			size += ((width+1) * (height+1)) << 3; // integral sum
			size += ((width+1) * (height+1)) << 3; // integral sqsum
			
			size += fft.calcRequiredChunkSize(ms);
        	
        	return IntMath.nextPow2(size);
        }
		
		public function TemplateMatchFFT()
		{
			//
		}
		
		public function setup(memOffset:int, width:int, height:int):void
		{
			var offset:int = memPtr = memOffset;
			
			var w2:int = IntMath.nextPow2(width);
			var h2:int = IntMath.nextPow2(height);
			var ms:int = IntMath.max(w2, h2);
			var area2:int = __cint(ms * ms);
			
			re_inPtr = offset;
			offset += (area2) << 3;
			im_inPtr = offset;
			offset += (area2) << 3;
			
			reTemplPtr = offset;
			offset += (area2) << 3;
			imTemplPtr = offset;
			offset += (area2) << 3;
			
			reImgPtr = offset;
			offset += (area2) << 3;
			imImgPtr = offset;
			offset += (area2) << 3;
			
			intSPtr = offset;
			offset += ((width + 1) * (height + 1)) << 3; // integral sum
			intSQPtr = offset;
			offset += ((width + 1) * (height + 1)) << 3; // integral sqsum
			
			fft.setup(offset, ms);
			//resultPtr = offset;
			
			last_fft_size = -1;
		}
		
		public function match64f(imgPtr:int, img_w:int, img_h:int,
                                 tmpPtr:int, tmp_w:int, tmp_h:int,
                                 resultPtr:int, method:int = 1, skipImgFFT:Boolean = false):void
		{
			// Calculate result size
			var corr_w:int = __cint(img_w - tmp_w + 1);
			var corr_h:int = __cint(img_h - tmp_h + 1);

			var out_w2:int = IntMath.nextPow2(img_w);
			var out_h2:int = IntMath.nextPow2(img_h);
			var tmp_size:int = __cint(tmp_w * tmp_h);
			
			var i:int, j:int;
			
			// calculate correlation in frequency domain
			// imageFFT * templateFFT
            fftImg(1, tmpPtr, 0, 0, tmp_w, tmp_h, tmp_w, out_w2, out_h2, re_inPtr, im_inPtr, reTemplPtr, imTemplPtr);

            if(!skipImgFFT)
            {
                fftImg(1, imgPtr, 0, 0, img_w, img_h, img_w, out_w2, out_h2, re_inPtr, im_inPtr, reImgPtr, imImgPtr);
            }
            multFFT(reImgPtr, imImgPtr, reTemplPtr, imTemplPtr, out_w2, out_h2);
            ifft(out_w2, out_h2, reTemplPtr, imTemplPtr, re_inPtr, im_inPtr, resultPtr, 0, 0, corr_w, corr_h, corr_w);

			if(method == CCORR)
			{
                return;
			}

			var DBL_EPSILON:Number = 2.2204460492503131E-16;
			var invArea:Number = 1.0 / Number(tmp_size);
			var invAreaSqrt:Number;
			var templNorm:Number = 0.0, templSum2:Number = 0.0;
			var q0:int, q1:int, q2:int, q3:int;
			var p0:int, p1:int, p2:int, p3:int;

            var sumw:int =   __cint(img_w + 1);
			var sumstep:int = __cint(sumw << 3);
			
			var numType:int = method == CCORR || method == CCORR_NORMED ? 0 :
							method == CCOEFF || method == CCOEFF_NORMED ? 1 : 2;
			var isNormed:Boolean = method == CCORR_NORMED ||
								method == SQDIFF_NORMED ||
								method == CCOEFF_NORMED;
            var compISQ:Boolean = isNormed || numType == 2;
			
			var math:*;
			__asm(__as3(Math), SetLocal(math));

            if( method == CCOEFF )
			{
				integralS64f(imgPtr, intSPtr, img_w, img_h);
				templMean = mean64f(tmpPtr, tmp_size);
			}
			else
			{
				integralSQ64f(imgPtr, intSPtr, intSQPtr, img_w, img_h);
				meanStdDev64f(tmpPtr, tmp_size);

				templNorm = templSdv * templSdv;
				
				if ( templNorm < DBL_EPSILON && method == CCOEFF_NORMED )
				{
					// set result to 1.0
					return;
				}
				
				templSum2 = templNorm + templMean * templMean;
				
				if( numType != 1 )
				{
					templMean = 0.0;
					templNorm = templSum2;
				}
				
				templSum2 /= invArea;
                __asm(__as3(math), __as3(templNorm), CallProperty(__as3(Math.sqrt), 1), SetLocal(templNorm));
                __asm(__as3(math), __as3(invArea), CallProperty(__as3(Math.sqrt), 1), SetLocal(invAreaSqrt));
				templNorm /= invAreaSqrt; // care of accuracy here

				q0 = intSQPtr;
				q1 = __cint(q0 + (tmp_w << 3));
				q2 = __cint(intSQPtr + tmp_h*sumstep);
				q3 = __cint(q2 + (tmp_w << 3));
			}
			
			p0 = intSPtr;
			p1 = __cint(p0 + (tmp_w << 3));
			p2 = __cint(intSPtr + tmp_h*sumstep);
			p3 = __cint(p2 + (tmp_w << 3));
			
			var rrow:int = resultPtr;
			var num4:Number = method != SQDIFF_NORMED ? 0 : 1;

			for (i = 0; i < corr_h; ++i)
			{
				var idx:int = __cint(i * sumstep);
				for (j = 0; j < corr_w; ++j)
				{
					var num:Number = Memory.readDouble(rrow);
					var t:Number, wndMean2:Number = 0.0, wndSum2:Number = 0.0;

					if ( numType == 1 )
					{
						t = Memory.readDouble(__cint(p0 + idx))
							- Memory.readDouble(__cint(p1 + idx))
							- Memory.readDouble(__cint(p2 + idx))
							+ Memory.readDouble(__cint(p3 + idx));
						wndMean2 += t * t;
						num -= t * templMean;
						wndMean2 *= invArea;
					}

					if ( compISQ )
					{
						t = Memory.readDouble(__cint(q0 + idx))
							- Memory.readDouble(__cint(q1 + idx))
							- Memory.readDouble(__cint(q2 + idx))
							+ Memory.readDouble(__cint(q3 + idx));
						wndSum2 += t;
						
						if( numType == 2 ) num = wndSum2 - 2.0*num + templSum2;
					}
					
					if( isNormed )
					{
						t = FastMath.max(wndSum2 - wndMean2, 0.0);
						if (t != 0.0)
						{
                            __asm(__as3(math), __as3(t), CallProperty(__as3(Math.sqrt), 1), SetLocal(t));
                            t *= templNorm;

                            var anum:Number = FastMath.abs(num);
                            if ( anum < t )
                            {
                                num /= t;
                            }
                            else if ( anum < t * 1.125 )
                            {
                                num = -1.0 + (Number(num > 0) << 1); // -1/1
                            } else {
                                num = num4;
                            }
						} else num = num4;
					}

					Memory.writeDouble(num, rrow);
					idx = __cint(idx + 8);
					rrow = __cint(rrow + 8);
				}
			}
		}

        public function match8u(imgPtr:int, img_w:int, img_h:int,
                                 tmpPtr:int, tmp_w:int, tmp_h:int,
                                 resultPtr:int, method:int = 1, skipImgFFT:Boolean = false):void
		{
			// Calculate result size
			var corr_w:int = __cint(img_w - tmp_w + 1);
			var corr_h:int = __cint(img_h - tmp_h + 1);

			var out_w2:int = IntMath.nextPow2(img_w);
			var out_h2:int = IntMath.nextPow2(img_h);
			var tmp_size:int = __cint(tmp_w * tmp_h);

			var i:int, j:int;
			
			// calculate correlation in frequency domain
			// imageFFT * templateFFT
            fftImg(0, tmpPtr, 0, 0, tmp_w, tmp_h, tmp_w, out_w2, out_h2, re_inPtr, im_inPtr, reTemplPtr, imTemplPtr);
			
			// debug - simply forward & inverse transform of image
			//fftImg(0, imgPtr, 0, 0, img_w, img_h, img_w, out_w2, out_h2, re_inPtr, im_inPtr, reImgPtr, imImgPtr);
			//ifft(out_w2, out_h2, reImgPtr, imImgPtr, re_inPtr, im_inPtr, resultPtr, 0, 0, corr_w, corr_h, corr_w);
			//return;
			
            if(!skipImgFFT)
            {
                fftImg(0, imgPtr, 0, 0, img_w, img_h, img_w, out_w2, out_h2, re_inPtr, im_inPtr, reImgPtr, imImgPtr);
            }
            multFFT(reImgPtr, imImgPtr, reTemplPtr, imTemplPtr, out_w2, out_h2);
            ifft(out_w2, out_h2, reTemplPtr, imTemplPtr, re_inPtr, im_inPtr, resultPtr, 0, 0, corr_w, corr_h, corr_w);
			
			if(method == CCORR)
			{
                return;
			}

			var DBL_EPSILON:Number = 2.2204460492503131E-16;
			var invArea:Number = 1.0 / Number(tmp_size);
			var invAreaSqrt:Number;
			var templNorm:Number = 0.0, templSum2:Number = 0.0;
			var q0:int, q1:int, q2:int, q3:int;
			var p0:int, p1:int, p2:int, p3:int;

            var sumw:int =   __cint(img_w + 1);
			var sumstep:int = __cint(sumw << 2);

			var numType:int = method == CCORR || method == CCORR_NORMED ? 0 :
							method == CCOEFF || method == CCOEFF_NORMED ? 1 : 2;
			var isNormed:Boolean = method == CCORR_NORMED ||
								method == SQDIFF_NORMED ||
								method == CCOEFF_NORMED;
            var compISQ:Boolean = isNormed || numType == 2;

			var math:*;
			__asm(__as3(Math), SetLocal(math));

            if( method == CCOEFF )
			{
				integralS8u(imgPtr, intSPtr, img_w, img_h);
				templMean = mean8u(tmpPtr, tmp_size);
			}
			else
			{
				integralSQ8u(imgPtr, intSPtr, intSQPtr, img_w, img_h);
				meanStdDev8u(tmpPtr, tmp_size);

				templNorm = templSdv * templSdv;

				if ( templNorm < DBL_EPSILON && method == CCOEFF_NORMED )
				{
					// set result to 1.0
					return;
				}

				templSum2 = templNorm + templMean * templMean;

				if( numType != 1 )
				{
					templMean = 0.0;
					templNorm = templSum2;
				}

				templSum2 /= invArea;
                __asm(__as3(math), __as3(templNorm), CallProperty(__as3(Math.sqrt), 1), SetLocal(templNorm));
                __asm(__as3(math), __as3(invArea), CallProperty(__as3(Math.sqrt), 1), SetLocal(invAreaSqrt));
				templNorm /= invAreaSqrt; // care of accuracy here

				q0 = intSQPtr;
				q1 = __cint(q0 + (tmp_w << 2));
				q2 = __cint(intSQPtr + tmp_h*sumstep);
				q3 = __cint(q2 + (tmp_w << 2));
			}

			p0 = intSPtr;
			p1 = __cint(p0 + (tmp_w << 2));
			p2 = __cint(intSPtr + tmp_h*sumstep);
			p3 = __cint(p2 + (tmp_w << 2));

			var rrow:int = resultPtr;
			var num4:Number = method != SQDIFF_NORMED ? 0 : 1;

			for (i = 0; i < corr_h; ++i)
			{
				var idx:int = __cint(i * sumstep);
				for (j = 0; j < corr_w; ++j)
				{
					var num:Number = Memory.readDouble(rrow);
					var t:Number, wndMean2:Number = 0.0, wndSum2:Number = 0.0;

					if ( numType == 1 )
					{
						t = __cint(Memory.readInt((p0 + idx))
							- Memory.readInt((p1 + idx))
							- Memory.readInt((p2 + idx))
							+ Memory.readInt((p3 + idx)));
						wndMean2 += t * t;
						num -= t * templMean;
						wndMean2 *= invArea;
					}

					if ( compISQ )
					{
						t = __cint(Memory.readInt((q0 + idx))
							- Memory.readInt((q1 + idx))
							- Memory.readInt((q2 + idx))
							+ Memory.readInt((q3 + idx)));
						wndSum2 += t;

						if( numType == 2 ) num = wndSum2 - 2.0*num + templSum2;
					}

					if( isNormed )
					{
						t = FastMath.max(wndSum2 - wndMean2, 0.0);
						if (t != 0.0)
						{
                            __asm(__as3(math), __as3(t), CallProperty(__as3(Math.sqrt), 1), SetLocal(t));
                            t *= templNorm;

                            var anum:Number = FastMath.abs(num);
                            if ( anum < t )
                            {
                                num /= t;
                            }
                            else if ( anum < t * 1.125 )
                            {
                                num = -1.0 + (Number(num > 0) << 1); // -1/1
                            } else {
                                num = num4;
                            }
						} else num = num4;
					}

					Memory.writeDouble(num, rrow);
					idx = __cint(idx + 4);
					rrow = __cint(rrow + 8);
				}
			}
		}

        protected var last_fft_size:int = -1;
        protected function fftImg(dataType:int, imgPtr:int, sx:int, sy:int, ex:int, ey:int, stride:int,
                                    out_w2:int, out_h2:int, re_tmp:int, im_tmp:int, re_out:int, im_out:int):void
        {
            var ptr0:int, ptr1:int, ptr2:int, ptr3:int;
            var spt0:int, spt1:int;
            var i:int, j:int;

            // check fft size and recom lut
            if(out_w2 != last_fft_size)
            {
                last_fft_size = out_w2;
				fft.init(out_w2);
            }

            var w2stride:int = (out_w2<<3);

            if(dataType == 0)
            {
                ptr3 = __cint(imgPtr + (sy*stride+sx));
                ptr1 = re_tmp;
                ptr2 = im_tmp;
                for (i = sy; i < ey; ++i)
                {
                    ptr0 = ptr3;
                    spt0 = ptr1;
                    spt1 = ptr2;
                    for (j = sx; j < ex; ++j)
                    {
                        Memory.writeDouble(Memory.readUnsignedByte(ptr0), ptr1);
                        Memory.writeDouble(0.0, ptr2);

                        ptr0 = __cint(ptr0 + 1);
                        ptr1 = __cint(ptr1 + 8);
                        ptr2 = __cint(ptr2 + 8);
                    }
                    // padd with zeros
                    j = __cint(j - sx);
                    for (; j < out_w2; ++j)
                    {
                        Memory.writeDouble(0.0, ptr1);
                        Memory.writeDouble(0.0, ptr2);
                        ptr1 = __cint(ptr1 + 8);
                        ptr2 = __cint(ptr2 + 8);
                    }
					fft.forward(spt0, spt1);
					
                    ptr3 = __cint(ptr3 + stride);
                }
            }
            else if(dataType == 1)
            {
                ptr3 = __cint(imgPtr + ((sy*stride+sx)<<3));
                ptr1 = re_tmp;
                ptr2 = im_tmp;
                for (i = sy; i < ey; ++i)
                {
                    ptr0 = ptr3;
                    spt0 = ptr1;
                    spt1 = ptr2;
                    for (j = sx; j < ex; ++j)
                    {
                        Memory.writeDouble(Memory.readDouble(ptr0), ptr1);
                        Memory.writeDouble(0.0, ptr2);

                        ptr0 = __cint(ptr0 + 8);
                        ptr1 = __cint(ptr1 + 8);
                        ptr2 = __cint(ptr2 + 8);
                    }
                    // padd with zeros
                    j = __cint(j - sx);
                    for (; j < out_w2; ++j)
                    {
                        Memory.writeDouble(0.0, ptr1);
                        Memory.writeDouble(0.0, ptr2);
                        ptr1 = __cint(ptr1 + 8);
                        ptr2 = __cint(ptr2 + 8);
                    }
					fft.forward(spt0, spt1);
                    ptr3 = __cint(ptr3 + (stride<<3));
                }
            }

            // check fft size and recom lut
            if(out_h2 != last_fft_size)
            {
                last_fft_size = out_h2;
				fft.init(out_h2);
            }
            // pass vertical
            ptr2 = re_out;
            ptr3 = im_out;
			for (j = 0; j < out_w2; ++j)
			{
                i = j << 3;
                ptr0 = __cint(re_tmp + i);
                ptr1 = __cint(im_tmp + i);
                spt0 = ptr2;
                spt1 = ptr3;
				for (i = sy; i < ey; ++i)
				{
					Memory.writeDouble(Memory.readDouble(ptr0), ptr2);
					Memory.writeDouble(Memory.readDouble(ptr1), ptr3);

					ptr0 = __cint(ptr0 + w2stride);
					ptr1 = __cint(ptr1 + w2stride);
					ptr2 = __cint(ptr2 + 8);
					ptr3 = __cint(ptr3 + 8);
				}
				// padd with zeros
                i = __cint(i - sy);
				for (; i < out_h2; ++i)
				{
					Memory.writeDouble(0.0, ptr2);
					Memory.writeDouble(0.0, ptr3);
					ptr2 = __cint(ptr2 + 8);
					ptr3 = __cint(ptr3 + 8);
				}
				fft.forward(spt0, spt1);
			}
        }

        protected function ifft(out_w2:int, out_h2:int, re_in:int, im_in:int, re_out:int, im_out:int,
                                resPtr:int, sx:int, sy:int, ex:int, ey:int, stride:int):void
        {
            var ptr0:int, ptr1:int, ptr2:int, ptr3:int, resp:int;
            var spt0:int, spt1:int;
            var i:int, j:int;

            // RE/IM data is transposed!

            // check fft size and recom lut
            if(out_h2 != last_fft_size)
            {
                last_fft_size = out_h2;
				fft.init(out_h2);
            }

            //var w2stride:int = (out_w2<<3);
            var h2stride:int = (out_h2<<3);
            var rstride8:int = __cint(stride<<3);

            // invert horizontal
			ptr0 = re_in;
			ptr1 = im_in;
			for (i = 0; i < out_w2; ++i)
			{
				fft.inverse(ptr0, ptr1);
				
				ptr0 = __cint(ptr0 + h2stride);
                ptr1 = __cint(ptr1 + h2stride);
			}

            // check fft size and recom lut
            if(out_w2 != last_fft_size)
            {
                last_fft_size = out_w2;
				fft.init(out_w2);
            }

            // invert vertical
            ptr2 = re_out;
			ptr3 = im_out;
            resp =  __cint(resPtr + ((sx+sy*stride) << 3));
            //var resw:int = __cint(ex - sx);
            var resh:int = __cint(ey - sy);
			for (j = 0; j < resh; ++j)
			{
                i = j << 3;
                ptr0 = __cint(re_in + i);
                ptr1 = __cint(im_in + i);
                spt0 = ptr2;
                spt1 = ptr3;
				for (i = 0; i < out_w2; ++i)
				{
					Memory.writeDouble(Memory.readDouble(ptr0), ptr2);
					Memory.writeDouble(Memory.readDouble(ptr1), ptr3);

					ptr0 = __cint(ptr0 + h2stride);
					ptr1 = __cint(ptr1 + h2stride);
					ptr2 = __cint(ptr2 + 8);
					ptr3 = __cint(ptr3 + 8);
				}

				fft.inverse(spt0, spt1);

                // render real part
                ptr0 = __cint(resp + j*rstride8);
                for(i = sx; i < ex; ++i)
                {
                    Memory.writeDouble(Memory.readDouble(spt0), ptr0);
                    spt0 = __cint(spt0 + 8);
                    ptr0 = __cint(ptr0 + 8);
                }
			}
        }

        protected function multFFT(re_a:int, im_a:int, re_b:int, im_b:int, w2:int, h2:int):void
        {
            // a.re * b.re - a.im * b.im
			// a.re * b.im + a.im * b.re
            // conj
            // re = are*bre + aim*bim;
            // im = aim*bre - are*bim;
            var are:Number, aim:Number, bre:Number, bim:Number;
			var end_ptr:int = __cint(re_b + ((w2*h2)<<3));
            var end_ptr8:int = __cint(end_ptr - 64 + 8);

			var ptr0:int = re_b;
			var ptr1:int = im_b;
            var d0:int = __cint(ptr0 - re_a);
			var d1:int = __cint(ptr1 - im_a);
			while(ptr0 < end_ptr8)
			{
				are = Memory.readDouble(__cint(ptr0-d0));
				aim = Memory.readDouble(__cint(ptr1-d1));
				bre = Memory.readDouble(ptr0);
				bim = Memory.readDouble(ptr1);
				//
                Memory.writeDouble(are * bre + aim * bim, ptr0);
				Memory.writeDouble(aim * bre - are * bim, ptr1);
				//
				ptr0 = __cint(ptr0 + 8);
				ptr1 = __cint(ptr1 + 8);
                //
                are = Memory.readDouble(__cint(ptr0-d0));
				aim = Memory.readDouble(__cint(ptr1-d1));
				bre = Memory.readDouble(ptr0);
				bim = Memory.readDouble(ptr1);
				//
                Memory.writeDouble(are * bre + aim * bim, ptr0);
				Memory.writeDouble(aim * bre - are * bim, ptr1);
				//
				ptr0 = __cint(ptr0 + 8);
				ptr1 = __cint(ptr1 + 8);
                //
                are = Memory.readDouble(__cint(ptr0-d0));
				aim = Memory.readDouble(__cint(ptr1-d1));
				bre = Memory.readDouble(ptr0);
				bim = Memory.readDouble(ptr1);
				//
                Memory.writeDouble(are * bre + aim * bim, ptr0);
				Memory.writeDouble(aim * bre - are * bim, ptr1);
				//
				ptr0 = __cint(ptr0 + 8);
				ptr1 = __cint(ptr1 + 8);
                //
                are = Memory.readDouble(__cint(ptr0-d0));
				aim = Memory.readDouble(__cint(ptr1-d1));
				bre = Memory.readDouble(ptr0);
				bim = Memory.readDouble(ptr1);
				//
                Memory.writeDouble(are * bre + aim * bim, ptr0);
				Memory.writeDouble(aim * bre - are * bim, ptr1);
				//
				ptr0 = __cint(ptr0 + 8);
				ptr1 = __cint(ptr1 + 8);
                //
                are = Memory.readDouble(__cint(ptr0-d0));
				aim = Memory.readDouble(__cint(ptr1-d1));
				bre = Memory.readDouble(ptr0);
				bim = Memory.readDouble(ptr1);
				//
                Memory.writeDouble(are * bre + aim * bim, ptr0);
				Memory.writeDouble(aim * bre - are * bim, ptr1);
				//
				ptr0 = __cint(ptr0 + 8);
				ptr1 = __cint(ptr1 + 8);
                //
                are = Memory.readDouble(__cint(ptr0-d0));
				aim = Memory.readDouble(__cint(ptr1-d1));
				bre = Memory.readDouble(ptr0);
				bim = Memory.readDouble(ptr1);
				//
                Memory.writeDouble(are * bre + aim * bim, ptr0);
				Memory.writeDouble(aim * bre - are * bim, ptr1);
				//
				ptr0 = __cint(ptr0 + 8);
				ptr1 = __cint(ptr1 + 8);
                //
                are = Memory.readDouble(__cint(ptr0-d0));
				aim = Memory.readDouble(__cint(ptr1-d1));
				bre = Memory.readDouble(ptr0);
				bim = Memory.readDouble(ptr1);
				//
                Memory.writeDouble(are * bre + aim * bim, ptr0);
				Memory.writeDouble(aim * bre - are * bim, ptr1);
				//
				ptr0 = __cint(ptr0 + 8);
				ptr1 = __cint(ptr1 + 8);
                //
                are = Memory.readDouble(__cint(ptr0-d0));
				aim = Memory.readDouble(__cint(ptr1-d1));
				bre = Memory.readDouble(ptr0);
				bim = Memory.readDouble(ptr1);
				//
                Memory.writeDouble(are * bre + aim * bim, ptr0);
				Memory.writeDouble(aim * bre - are * bim, ptr1);
				//
				ptr0 = __cint(ptr0 + 8);
				ptr1 = __cint(ptr1 + 8);
                //
			}
            while(ptr0 < end_ptr)
			{
				are = Memory.readDouble(__cint(ptr0-d0));
				aim = Memory.readDouble(__cint(ptr1-d1));
				bre = Memory.readDouble(ptr0);
				bim = Memory.readDouble(ptr1);
				//
                Memory.writeDouble(are * bre + aim * bim, ptr0);
				Memory.writeDouble(aim * bre - are * bim, ptr1);
				//
				ptr0 = __cint(ptr0 + 8);
				ptr1 = __cint(ptr1 + 8);
            }
        }
		
		protected function integralS64f(imgPtr:int, sumPtr:int, w:int, h:int):void
		{
			var w1:int = __cint(w + 1);
			var w18:int = w1 << 3;
			var y:int, x:int;
			var s:Number;
			
			var ptrs:int = sumPtr;
			for ( x = 0; x < w1; ++x )
			{
				Memory.writeDouble(0.0, ptrs);
				ptrs = __cint(ptrs + 8);
			}
			ptrs = __cint(ptrs + 8);
			
			for ( y = 0; y < h; ++y)
			{
				s = 0;
				Memory.writeDouble(0.0, __cint(ptrs-8));
                var loc_ps:int = ptrs;
				for ( x = 0; x < w; ++x )
				{
					s = (Memory.readDouble(imgPtr) + s);
					Memory.writeDouble(s + Memory.readDouble(__cint(loc_ps - w18)), loc_ps);
					imgPtr = __cint(imgPtr + 8);
					loc_ps = __cint(loc_ps + 8);
				}
				ptrs = __cint(ptrs + w18);
			}
		}
		protected function integralSQ64f(imgPtr:int, sumPtr:int, sqsumPtr:int, w:int, h:int):void
		{
			var w1:int = __cint(w + 1);
			var w18:int = w1 << 3;
			var y:int, x:int;
			var s:Number, sq:Number;
			
			var ptri:int = imgPtr;
			var ptrs:int = sumPtr;
			var ptrsq:int = sqsumPtr;
			for ( x = 0; x < w1; ++x )
			{
				Memory.writeDouble(0.0, ptrs);
				Memory.writeDouble(0.0, ptrsq);
				ptrs = __cint(ptrs + 8);
				ptrsq = __cint(ptrsq + 8);
			}
			ptrs = __cint(ptrs + 8);
			ptrsq = __cint(ptrsq + 8);
			
			for ( y = 0; y < h; ++y)
			{
				s = sq = 0;
				Memory.writeDouble(0.0, __cint(ptrs - 8));
				Memory.writeDouble(0.0, __cint(ptrsq - 8));
                var loc_ps:int = ptrs;
                var loc_psq:int = ptrsq;
				for ( x = 0; x < w; ++x )
				{
					var v:Number = Memory.readDouble(ptri);
					s = (v + s);
					sq = (v * v + sq);
					
					Memory.writeDouble(s + Memory.readDouble(__cint(loc_ps - w18)), loc_ps);
					Memory.writeDouble(sq + Memory.readDouble(__cint(loc_psq - w18)), loc_psq);
					//
					ptri = __cint(ptri + 8);
					loc_ps = __cint(loc_ps + 8);
					loc_psq = __cint(loc_psq + 8);
				}
				ptrs = __cint(ptrs + w18);
				ptrsq = __cint(ptrsq + w18);
			}
			/*
			// debug
			var bx:int = 20;
			var by:int = 10;
			var bw:int = 50;
			var bh:int = 30;
			s = sq = 0;
			for ( y = by; y < by+bh; ++y)
			{
				ptri = __cint(imgPtr + y*w+bx);
				for ( x = bx; x < bx+bw; ++x )
				{
					v = Memory.readUnsignedByte(ptri);
					s = __cint(v + s);
					sq = __cint(v * v + sq);
					
					ptri = __cint(ptri + 1);
				}
			}
			var q0:int, q1:int, q2:int, q3:int;
			var p0:int, p1:int, p2:int, p3:int;
			q0 = intSQPtr + ((bx+by*w1)<<3);
			q1 = __cint(q0 + (bw << 3));
			q2 = __cint(intSQPtr + ((bx+(by+bh)*w1)<<3));
			q3 = __cint(q2 + (bw << 3));
			var idx:int = 0;
			var t:Number = Memory.readDouble(__cint(q0))
							- Memory.readDouble(__cint(q1))
							- Memory.readDouble(__cint(q2))
							+ Memory.readDouble(__cint(q3));
			
			p0 = intSPtr + ((bx+by*w1)<<3);
			p1 = __cint(p0 + (bw << 3));
			p2 = __cint(intSPtr + ((bx+(by+bh)*w1)<<3));
			p3 = __cint(p2 + (bw << 3));
			var t2:Number = Memory.readDouble(__cint(p0))
							- Memory.readDouble(__cint(p1))
							- Memory.readDouble(__cint(p2))
							+ Memory.readDouble(__cint(p3));
			throw new Error([sq, t, s, t2]);
			*/
		}

        protected function integralS8u(imgPtr:int, sumPtr:int, w:int, h:int):void
		{
			var w1:int = __cint(w + 1);
			var w14:int = w1 << 2;
			var y:int, x:int;
			var s:int;

			var ptrs:int = sumPtr;
			for ( x = 0; x < w1; ++x )
			{
				Memory.writeInt(0, ptrs);
				ptrs = __cint(ptrs + 4);
			}
			ptrs = __cint(ptrs + 4);

			for ( y = 0; y < h; ++y)
			{
				s = 0;
				Memory.writeInt(0, __cint(ptrs-4));
                var loc_ps:int = ptrs;
				for ( x = 0; x < w; ++x )
				{
					s = __cint(Memory.readUnsignedByte(imgPtr) + s);
					Memory.writeInt(__cint(s + Memory.readInt(loc_ps - w14)), loc_ps);
					imgPtr = __cint(imgPtr + 1);
					loc_ps = __cint(loc_ps + 4);
				}
				ptrs = __cint(ptrs + w14);
			}
		}
		protected function integralSQ8u(imgPtr:int, sumPtr:int, sqsumPtr:int, w:int, h:int):void
		{
			var w1:int = __cint(w + 1);
			var w14:int = w1 << 2;
			var y:int, x:int;
			var s:int, sq:int;

			var ptri:int = imgPtr;
			var ptrs:int = sumPtr;
			var ptrsq:int = sqsumPtr;
			for ( x = 0; x < w1; ++x )
			{
				Memory.writeInt(0, ptrs);
				Memory.writeInt(0, ptrsq);
				ptrs = __cint(ptrs + 4);
				ptrsq = __cint(ptrsq + 4);
			}
			ptrs = __cint(ptrs + 4);
			ptrsq = __cint(ptrsq + 4);

			for ( y = 0; y < h; ++y)
			{
				s = sq = 0;
				Memory.writeInt(0, __cint(ptrs - 4));
				Memory.writeInt(0, __cint(ptrsq - 4));
                var loc_ps:int = ptrs;
                var loc_psq:int = ptrsq;
				for ( x = 0; x < w; ++x )
				{
					var v:int = Memory.readUnsignedByte(ptri);
					s = __cint(v + s);
					sq = __cint(v * v + sq);

					Memory.writeInt(__cint(s + Memory.readInt(loc_ps - w14)), loc_ps);
					Memory.writeInt(__cint(sq + Memory.readInt(loc_psq - w14)), loc_psq);
					//
					ptri = __cint(ptri + 1);
					loc_ps = __cint(loc_ps + 4);
					loc_psq = __cint(loc_psq + 4);
				}
				ptrs = __cint(ptrs + w14);
				ptrsq = __cint(ptrsq + w14);
			}
		}
		
		protected function mean64f(imgPtr:int, len:int):Number
		{
			var sum:Number = 0;
			var end:int = __cint(imgPtr + (len<<3));
			while (imgPtr < end)
			{
				sum = (Memory.readDouble(imgPtr) + sum);
				imgPtr = __cint(imgPtr + 8);
			}
			templMean = sum / Number(len);
			return templMean;
		}
		protected function meanStdDev64f(imgPtr:int, len:int):void
		{
			var sum:Number = 0;
			var sqsum:Number = 0;
			var end:int = __cint(imgPtr + (len<<3));
			while (imgPtr < end)
			{
				var s:Number = Memory.readDouble(imgPtr);
				sum = s + sum;
				sqsum = s*s + sqsum;
				imgPtr = __cint(imgPtr + 8);
			}
			
			var scale:Number = 1.0 / Number(len);
			templMean = sum * scale;
			templSdv = Math.sqrt( sqsum * scale - templMean * templMean );
		}

        protected function mean8u(imgPtr:int, len:int):Number
		{
			var sum:int = 0;
			var end:int = __cint(imgPtr + len);
			while (imgPtr < end)
			{
				sum = __cint(Memory.readUnsignedByte(imgPtr) + sum);
				imgPtr = __cint(imgPtr + 1);
			}
			templMean = Number(sum) / Number(len);
			return templMean;
		}
		protected function meanStdDev8u(imgPtr:int, len:int):void
		{
			var sum:int = 0;
			var sqsum:int = 0;
			var end:int = __cint(imgPtr + len);
			while (imgPtr < end)
			{
				var s:int = Memory.readUnsignedByte(imgPtr);
				sum = __cint(s + sum);
				sqsum = __cint(s*s + sqsum);
				imgPtr = __cint(imgPtr + 1);
			}

			var scale:Number = 1.0 / Number(len);
			templMean = Number(sum) * scale;
			templSdv = Math.sqrt( sqsum * scale - templMean * templMean );
		}
		
	}
}