package ru.inspirit.image.mem
{
	
	import apparat.asm.*;
	import apparat.inline.Macro;
	import apparat.math.FastMath;
	import apparat.memory.Memory;
	/**
	 * @author Eugene Zatepyakin
	 */
	public final class MemImageMacro extends Macro
	{	
		public static function fillUCharBuffer(ptr:int, img:Vector.<uint>):void
		{
			var i:int = 0;
			var n:int = img.length;
			var bit32:int = __cint((n >> 5) + 1);
			
			__asm(
				'loop:',
				DecLocalInt(bit32),
				GetLocal(bit32),
				PushByte(0),
				IfEqual('endLoop')
				);
					__beginRepeat(32);
					//MemImageMacro.fillUCharPass(ptr, i, img);
					__asm(
						GetLocal(img),
						GetLocal(i),
						GetProperty(AbcMultinameL(AbcNamespaceSet(AbcNamespace(NamespaceKind.PACKAGE, "")))),
						ConvertInt,
						GetLocal(ptr),
						SetByte,
						IncLocalInt(i),
						IncLocalInt(ptr)
					);
					__endRepeat();
			__asm(
				Jump('loop'),
				'endLoop:'
				);
			__asm(
				'loop1:',
				GetLocal(i),
				GetLocal(n),
				IfEqual('endLoop1')
				);
					//MemImageMacro.fillUCharPass(ptr, i, img);
					__asm(
						GetLocal(img),
						GetLocal(i),
						GetProperty(AbcMultinameL(AbcNamespaceSet(AbcNamespace(NamespaceKind.PACKAGE, "")))),
						ConvertInt,
						GetLocal(ptr),
						SetByte,
						IncLocalInt(i),
						IncLocalInt(ptr)
					);
			__asm(
				Jump('loop1'),
				'endLoop1:'
			);
		}
		
		public static function fillIntBuffer(ptr:int, img:Vector.<uint>):void
		{
			var i:int = 0;
			var n:int = img.length;
			var bit32:int = __cint((n >> 5) + 1);
			
			__asm(
				'loop:',
				DecLocalInt(bit32),
				GetLocal(bit32),
				PushByte(0),
				IfEqual('endLoop')
				);
					__beginRepeat(32);
					//MemImageMacro.fillIntPass(ptr, i, img);
					__asm(
						GetLocal(img),
						GetLocal(i),
						GetProperty(AbcMultinameL(AbcNamespaceSet(AbcNamespace(NamespaceKind.PACKAGE, "")))),
						ConvertInt,
						GetLocal(ptr),
						SetInt,
						IncLocalInt(i),
						GetLocal(ptr),
						PushByte(4),
						AddInt,
						SetLocal(ptr)
					);
					__endRepeat();
			__asm(
				Jump('loop'),
				'endLoop:'
				);
			__asm(
				'loop1:',
				GetLocal(i),
				GetLocal(n),
				IfEqual('endLoop1')
				);
					//MemImageMacro.fillIntPass(ptr, i, img);
					__asm(
						GetLocal(img),
						GetLocal(i),
						GetProperty(AbcMultinameL(AbcNamespaceSet(AbcNamespace(NamespaceKind.PACKAGE, "")))),
						ConvertInt,
						GetLocal(ptr),
						SetInt,
						IncLocalInt(i),
						GetLocal(ptr),
						PushByte(4),
						AddInt,
						SetLocal(ptr)
					);
			__asm(
				Jump('loop1'),
				'endLoop1:'
			);
		}
		
		// compute gradient using Sobel kernel (1/8) * [1 2 1] * [-1 0 1]^T (sigma^2 = 0.5)
		public static function gradientSobel(imgPtr:int, gradXPtr:int, gradYPtr:int, w:int, h:int):void
		{
			var eh:int = __cint(h - 1);
			var ew:int = __cint(w - 1); 
			var stride4:int = w << 2;
			var y:int, x:int;

			var p:int = __cint( imgPtr + w );
			var pu:int = __cint( p - w );
			var pd:int = __cint( p + w );
			var qx:int = __cint( gradXPtr + stride4 );
			var qy:int = __cint( gradYPtr + stride4 );
			// temporary data structures; use top rows of output, since
			// they are not filled in until the very end
			var t0:int = gradXPtr;
			var t1:int = gradYPtr;
			
			var a:int, b:int;
			var shift:int = 3;
			
			for(y = 1; y < eh; ++y)
			{
				var _t0:int = t0;
				var _t1:int = t1;
				var _p:int = p;
				var _pu:int = pu;
				var _pd:int = pd;
				
				// convolve vertical
				for(x = 0; x < w; ++x)
				{
					a = Memory.readUnsignedByte(_pd);
					b = Memory.readUnsignedByte(_pu);
					Memory.writeInt(__cint(a-b), _t0);
					Memory.writeInt(__cint(b + a
											+ (Memory.readUnsignedByte(_p)<<1)
									), _t1);
					//
					__asm(IncLocalInt(_p), IncLocalInt(_pu), IncLocalInt(_pd));
					_t0 = __cint(_t0 + 4);
					_t1 = __cint(_t1 + 4);
				}
				
				var _qx:int = qx;
				var _qy:int = qy;
				_t0 = t0;
				_t1 = t1;
				
				a = Memory.readInt(_t0);
				
				Memory.writeInt(__cint(	(Memory.readInt(_t1+4) - Memory.readInt(_t1)) >> shift
										), _qx);
				Memory.writeInt(__cint( (a + Memory.readInt(_t0+4)
										+ (a<<1)) >> shift
										), _qy);
				
				_qx = __cint(_qx + 4); _qy = __cint(_qy + 4);
				_t0 = __cint(_t0 + 4); _t1 = __cint(_t1 + 4);
				
				// convolve horizontal
				for(x = 1; x < ew; ++x)
				{				
					Memory.writeInt(__cint(	(Memory.readInt(_t1+4) - Memory.readInt(_t1-4)) >> shift
											), _qx);
					Memory.writeInt(__cint( (Memory.readInt(_t0-4) + Memory.readInt(_t0+4)
											+ (Memory.readInt(_t0)<<1)) >> shift
											), _qy);
					_qx = __cint(_qx + 4); _qy = __cint(_qy + 4);
					_t0 = __cint(_t0 + 4); _t1 = __cint(_t1 + 4);
				}
				
				a = Memory.readInt(_t0);
				
				Memory.writeInt(__cint(	(Memory.readInt(_t1) - Memory.readInt(_t1-4)) >> shift
										), _qx);
				Memory.writeInt(__cint( (Memory.readInt(_t0-4) + a
										+ (a<<1)) >> shift
										), _qy);
				
				p = __cint(p + w);
				pu = __cint(pu + w);
				pd = __cint( pd + w );
				qx = __cint( qx + stride4 );
				qy = __cint( qy + stride4 );
			}
			
			// copy values into top and bottom row
			// i skip it to avoid overhead
		}
		
		// compute gradient using Sharr kernel (1/32) * [3 10 3] * [-1 0 1]^T (sigma^2 = 1.1)
		public static function gradientSharr(imgPtr:int, gradXPtr:int, gradYPtr:int, w:int, h:int):void
		{
			var eh:int = __cint(h - 1);
			var ew:int = __cint(w - 1); 
			var stride4:int = w << 2;
			var y:int, x:int;

			var p:int = __cint( imgPtr + w );
			var pu:int = __cint( p - w );
			var pd:int = __cint( p + w );
			var qx:int = __cint( gradXPtr + stride4 );
			var qy:int = __cint( gradYPtr + stride4 );
			// temporary data structures; use top rows of output, since
			// they are not filled in until the very end
			var t0:int = gradXPtr;
			var t1:int = gradYPtr;
			
			var a:int, b:int;
			var shift:int = 5;
			var k0:int = 10;
			var k1:int = 3;
			
			for(y = 1; y < eh; ++y)
			{
				var _t0:int = t0;
				var _t1:int = t1;
				var _p:int = p;
				var _pu:int = pu;
				var _pd:int = pd;
				
				// convolve vertical
				for(x = 0; x < w; ++x)
				{
					a = Memory.readUnsignedByte(_pd);
					b = Memory.readUnsignedByte(_pu);
					Memory.writeInt(__cint(a-b), _t0);
					Memory.writeInt(__cint((b + a)*k1
											+ Memory.readUnsignedByte(_p)*k0
									), _t1);
					//
					__asm(IncLocalInt(_p), IncLocalInt(_pu), IncLocalInt(_pd));
					_t0 = __cint(_t0 + 4);
					_t1 = __cint(_t1 + 4);
				}
				
				var _qx:int = qx;
				var _qy:int = qy;
				_t0 = t0;
				_t1 = t1;
				
				a = Memory.readInt(_t0);
				
				Memory.writeInt(__cint(	(Memory.readInt(_t1+4) - Memory.readInt(_t1)) >> shift
										), _qx);
				Memory.writeInt(__cint( ( (a + Memory.readInt(_t0+4))*k1
										+ (a*k0) ) >> shift
										), _qy);
				
				_qx = __cint(_qx + 4); _qy = __cint(_qy + 4);
				_t0 = __cint(_t0 + 4); _t1 = __cint(_t1 + 4);
				
				// convolve horizontal
				for(x = 1; x < ew; ++x)
				{				
					Memory.writeInt(__cint(	(Memory.readInt(_t1+4) - Memory.readInt(_t1-4)) >> shift
											), _qx);
					Memory.writeInt(__cint( ((Memory.readInt(_t0-4) + Memory.readInt(_t0+4))*k1
											+ (Memory.readInt(_t0)*k0)) >> shift
											), _qy);
					_qx = __cint(_qx + 4); _qy = __cint(_qy + 4);
					_t0 = __cint(_t0 + 4); _t1 = __cint(_t1 + 4);
				}
				
				a = Memory.readInt(_t0);
				
				Memory.writeInt(__cint(	(Memory.readInt(_t1) - Memory.readInt(_t1-4)) >> shift
										), _qx);
				Memory.writeInt(__cint( ((Memory.readInt(_t0-4) + a)*k1
										+ (a*k0)) >> shift
										), _qy);
				
				p = __cint(p + w);
				pu = __cint(pu + w);
				pd = __cint( pd + w );
				qx = __cint( qx + stride4 );
				qy = __cint( qy + stride4 );
			}
			
			// copy values into top and bottom row
			// i skip it to avoid overhead
		}
		
		/**
		 * image gradient magnitude computation using
		 * Prewitt horizontal [-1 0 1] and vertical [-1 0 1]^T kernels
		 * @param imgPtr	memory offset to input UCHAR image
		 * @param gradPtr	memory offset to output INT image 
		 */
		public static function computeImageGradientMagnitude(imgPtr:int, gradPtr:int, w:int, h:int):void
		{
			var x:int, y:int, a:int, b:int, c:int, d:int;
			var img_xendp:int, img_endp:int;

			img_endp = __cint(imgPtr + w*(h-1));
			
			for (; imgPtr < img_endp; ) 
			{
		        a = Memory.readUnsignedByte(imgPtr);
		        c = Memory.readUnsignedByte(__cint(imgPtr+w));
		        
		        img_xendp = __cint(imgPtr + w - 1);
		        for (; imgPtr < img_xendp; ) 
		        {
		            __asm(IncLocalInt(imgPtr));
		
		            b = Memory.readUnsignedByte(imgPtr);
		            d = Memory.readUnsignedByte(__cint(imgPtr+w));
		
		            a = __cint(d - a);
		            c = __cint(b - c);
		            x = __cint(a + c);
		            y = __cint(a - c);
		
		            a = b;
		            c = d;

					Memory.writeInt(__cint(x * x + y * y), gradPtr);
					__asm(GetLocal(gradPtr),PushByte(4),AddInt,SetLocal(gradPtr));
		        }		
		        __asm(IncLocalInt(imgPtr));
		        __asm(GetLocal(gradPtr),PushByte(4),AddInt,SetLocal(gradPtr));
		    }
		}
		
		// Prewitt horizontal [-1 0 1] and vertical [-1 0 1]^T kernels
		public static function computeImageDxDyGradient(imgPtr:int, gradXPtr:int, gradYPtr:int, w:int, h:int):void
		{
			var x:int, y:int, a:int, b:int, c:int, d:int;
			var img_xendp:int, img_endp:int;

			img_endp = __cint(imgPtr + w*(h-1));
			
			for (; imgPtr < img_endp; ) 
			{
		        a = Memory.readUnsignedByte(imgPtr);
		        c = Memory.readUnsignedByte(__cint(imgPtr+w));
		        
		        img_xendp = __cint(imgPtr + w - 1);
		        for (; imgPtr < img_xendp; ) 
		        {
		            __asm(IncLocalInt(imgPtr));
		
		            b = Memory.readUnsignedByte(imgPtr);
		            d = Memory.readUnsignedByte(__cint(imgPtr+w));
		
		            a = __cint(d - a);
		            c = __cint(b - c);
		            x = __cint(a + c);
		            y = __cint(a - c);
		
		            a = b;
		            c = d;

					//Memory.writeInt(__cint(x * x + y * y), gradPtr);
					Memory.writeInt(x, gradXPtr);
					Memory.writeInt(y, gradYPtr);
					__asm(GetLocal(gradXPtr),PushByte(4),AddInt,SetLocal(gradXPtr));
					__asm(GetLocal(gradYPtr),PushByte(4),AddInt,SetLocal(gradYPtr));
		        }		
		        __asm(IncLocalInt(imgPtr));
		        __asm(GetLocal(gradXPtr),PushByte(4),AddInt,SetLocal(gradXPtr));
		        __asm(GetLocal(gradYPtr),PushByte(4),AddInt,SetLocal(gradYPtr));
		    }
		}
		
		public static function computeIntegralImage(srcPtr:int, dstPtr:int, w:int, h:int):void
		{
			var rowI:int = srcPtr;
			var rowII:int = dstPtr;
			var sum:int = 0;
			var i:int = __cint(w + 1);
			var j:int;
			
			__asm(
					'loop:',
					DecLocalInt(i),
					GetLocal(i),
					PushByte(0),
					IfEqual('endLoop') );
			//      
			__asm( GetLocal(sum),GetLocal(rowI),GetByte,AddInt,SetLocal(sum),GetLocal(sum),GetLocal(rowII),SetInt );
			__asm( IncLocalInt( rowI ), GetLocal( rowII ), PushByte( 4 ), AddInt, SetLocal(rowII));
			//
			__asm(
					Jump('loop'),
					'endLoop:'
					);
			// 
	
			var prowII:int = __cint(dstPtr - rowII);
			var endI:int = __cint(srcPtr + (w*h));
			var endIm4:int = __cint(endI - 4 + 1);
			sum = i = 0;
			while( rowI < endIm4 )
			{
				j = int(i<w);
				i=__cint(j*i+1);
				sum = __cint(j*sum+Memory.readUnsignedByte(rowI));
				Memory.writeInt(__cint(sum+Memory.readInt(prowII+rowII)), rowII);
				__asm( IncLocalInt(rowI) );
				rowII = __cint(rowII + 4);
				
				j = int(i<w);
				i=__cint(j*i+1);
				sum = __cint(j*sum+Memory.readUnsignedByte(rowI));
				Memory.writeInt(__cint(sum+Memory.readInt(prowII+rowII)), rowII);
				__asm( IncLocalInt(rowI) );
				rowII = __cint(rowII + 4);
				
				j = int(i<w);
				i=__cint(j*i+1);
				sum = __cint(j*sum+Memory.readUnsignedByte(rowI));
				Memory.writeInt(__cint(sum+Memory.readInt(prowII+rowII)), rowII);
				__asm( IncLocalInt(rowI) );
				rowII = __cint(rowII + 4);
				
				j = int(i<w);
				i=__cint(j*i+1);
				sum = __cint(j*sum+Memory.readUnsignedByte(rowI));
				Memory.writeInt(__cint(sum+Memory.readInt(prowII+rowII)), rowII);
				__asm( IncLocalInt(rowI) );
				rowII = __cint(rowII+4);
			}	
			
			while( rowI < endI )
			{
				j = int(i<w);
				i=__cint(j*i+1);
				sum = __cint(j*sum+Memory.readUnsignedByte(rowI));
				Memory.writeInt(__cint(sum+Memory.readInt(prowII+rowII)), rowII);
				__asm( IncLocalInt(rowI) );
				rowII = __cint(rowII + 4);
			}
		}
		
		public static function pyrDown(fromPtr:int, toPtr:int, newW:int, newH:int):void
		{
			var i:int;
			var ow:int = newW << 1;
			var out:int = toPtr;
			var rem:int = __cint((newW >> 5) + 1);
			var tail:int = __cint((newW % 32) + 1);
			var br:int;
			
			var row0:int = fromPtr;
			var row1:int = __cint(row0 + ow);

			for(i = 0; i < newH; ++i)
			{
				
				br = rem;
				__asm(
					'loop:',
					DecLocalInt(br),
					GetLocal(br),
					PushByte(0),
					IfEqual('endLoop')
					);
                    __beginRepeat(32);
					MemImageMacro.pyrPass(row0, row1, out);
					__endRepeat();
				__asm(
					Jump('loop'),
					'endLoop:'
				);
				// finish
				br = tail;
				__asm(
					'loop1:',
					DecLocalInt(br),
					GetLocal(br),
					PushByte(0),
					IfEqual('endLoop1')
					);
					MemImageMacro.pyrPass(row0, row1, out);
				__asm(
					Jump('loop1'),
					'endLoop1:'
					);
					
				row0 = __cint(row0 + ow);
				row1 = __cint(row0 + ow);
			}
		}
		
		public static function downSample2x2(fromPtr:int, toPtr:int, newW:int, newH:int):void
		{
			var i:int;
			var ow:int = newW << 1;
			var out:int = toPtr;
			var rem:int = __cint((newW >> 5) + 1);
			var tail:int = __cint((newW % 32) + 1);
			var br:int;
			
			var row0:int = fromPtr;
			var skip:int = __cint(ow - (ow&1));

			for(i = 0; i < newH; ++i)
			{
				
				br = rem;
				__asm(
					'loop:',
					DecLocalInt(br),
					GetLocal(br),
					PushByte(0),
					IfEqual('endLoop')
					);
					__beginRepeat( 32 );
					Memory.writeByte( Memory.readUnsignedByte( row0 ), out );
					__asm(IncLocalInt(out));
					row0 = __cint(row0 + 2);
					__endRepeat();
				__asm(
					Jump('loop'),
					'endLoop:'
				);
				// finish
				br = tail;
				__asm(
					'loop1:',
					DecLocalInt(br),
					GetLocal(br),
					PushByte(0),
					IfEqual('endLoop1')
					);
					Memory.writeByte( Memory.readUnsignedByte( row0 ), out );
					__asm(IncLocalInt(out));
					row0 = __cint(row0 + 2);
				__asm(
					Jump('loop1'),
					'endLoop1:'
					);
					
				row0 = __cint(row0 + skip);
			}
		}
		
		public static function getQuadrangleSubPix(
													src:int, src_w:int, src_h:int, 
													dst:int, dst_w:int, dst_h:int, 
													mat:Vector.<Number>, convPtr:int):void
		{
			var x:int, y:int;
			var dx:Number = (dst_w - 1) * 0.5;
			var dy:Number = (dst_h - 1) * 0.5;
			var A11:Number = mat[0]; var A12:Number = mat[1];
			var A21:Number = mat[3]; var A22:Number = mat[4];
			var A13:Number = mat[2] - A11 * dx - A12 * dy;
			var A23:Number = mat[5] - A21 * dx - A22 * dy;
			
			var src_wm3:int = __cint(src_w - 3);
			var src_hm3:int = __cint(src_h - 3);
			var src_wm1:int = __cint(src_w - 1);
			var src_hm1:int = __cint(src_h - 1);
			var val0:int, val1:int, val2:int, val3:int;
			
			for (y = 0; y < dst_h; ++y)
			{
				var xs:Number = A12 * y + A13;
				var ys:Number = A22 * y + A23;
				var xe:Number = A11 * (dst_w - 1) + A12 * y + A13;
				var ye:Number = A21 * (dst_w - 1) + A22 * y + A23;
				
				var chk:int = int(xs-1 < src_wm3) &
								int(ys-1 < src_hm3) &
								int(xe-1 < src_wm3) &
								int(ye-1 < src_hm3);
				if (chk)
				{
					for( x = 0; x < dst_w; ++x )
					{
						var ixs:int = ( xs );
						var iys:int = ( ys );
						var ptr:int = __cint(src + src_w*iys + ixs);
						var a:Number = xs - Number(ixs);
						var b:Number = ys - Number(iys);
						var a1:Number = 1.0 - a;
						//var p0:Number = cvt(ptr[0])*a1 + cvt(ptr[1])*a;
						//var p1:Number = cvt(ptr[src_step])*a1 + cvt(ptr[src_step+1])*a;
						MemImageMacro.cvt8u32f(ptr, val0, convPtr); ptr = __cint(ptr + 1);
						MemImageMacro.cvt8u32f(ptr, val1, convPtr); ptr = __cint(ptr + src_w);
						MemImageMacro.cvt8u32f(ptr, val3, convPtr); ptr = __cint(ptr - 1);
						MemImageMacro.cvt8u32f(ptr, val2, convPtr);
						var p0:Number = val0*a1 + val1*a;
						var p1:Number = val2*a1 + val3*a;
						xs += A11;
						ys += A21;
						//dst[x] = (p0 + b * (p1 - p0));
						Memory.writeDouble(p0 + b * (p1 - p0), dst);
						dst = __cint(dst + 8);
					}                  
				}
				else
				{
					for( x = 0; x < dst_w; ++x )
					{
						ixs = ( xs );
						iys = ( ys );
						a = xs - Number(ixs);
						b = ys - Number(iys);
						a1 = 1.0 - a;
						var ptr0:int, ptr1:int;
						xs += A11; ys += A21;
						
						if ( iys < src_hm1 )
						{
							ptr0 = __cint(src + src_w * iys);
							ptr1 = __cint(ptr0 + src_w);
						}
						else
						{
							ptr0 = __cint( src + (int(iys >= 0) * src_hm1) * src_w );
							ptr1 = ptr0;
						}
						
						if( ixs < src_wm1 )
						{
							//p0 = cvt(ptr0[ixs])*a1 + cvt(ptr0[ixs+1])*a;
							//p1 = cvt(ptr1[ixs])*a1 + cvt(ptr1[ixs+1])*a;
							ptr0 = __cint(ptr0 + ixs);
							ptr1 = __cint(ptr1 + ixs);
							MemImageMacro.cvt8u32f(ptr0, val0, convPtr); ptr0 = __cint(ptr0 + 1);
							MemImageMacro.cvt8u32f(ptr0, val1, convPtr); 
							MemImageMacro.cvt8u32f(ptr1, val2, convPtr); ptr1 = __cint(ptr1 + 1);
							MemImageMacro.cvt8u32f(ptr1, val3, convPtr); 
							p0 = val0*a1 + val1*a;
							p1 = val2*a1 + val3*a;
						}
						else
						{
							//ixs = ixs < 0 ? 0 : src_wm1;
							//p0 = cvt(ptr0[ixs]); 
							//p1 = cvt(ptr1[ixs]);
							ixs = __cint(int(ixs >= 0) * src_wm1);
							ptr0 = __cint(ptr0 + ixs);
							ptr1 = __cint(ptr1 + ixs);
							MemImageMacro.cvt8u32f(ptr0, val0, convPtr);
							MemImageMacro.cvt8u32f(ptr1, val1, convPtr);
							p0 = val0;
							p1 = val1;
						}
						//dst[x] = cast_macro(p0 + b * (p1 - p0));
						Memory.writeDouble(p0 + b * (p1 - p0), dst);
						dst = __cint(dst + 8);
					}
				}
			}
		}
		
		public static function cvt8u32f(src:int, dst:int, convPtr:int):void
		{
			dst = __cint(Memory.readInt( convPtr + ((Memory.readUnsignedByte( src ) + 256) << 2) ));
		}
		
		public static function bilinearInterpolation(imgPtr:int, stride:int, x:Number, y:Number, val:Number):void
		{
			var mnx:int = x;
			var mny:int = y;
			var mxx:int = FastMath.rint( x + 0.4999 );
			var mxy:int = FastMath.rint( y + 0.4999 );
			
			var alfa:Number = mxx - x;
			var beta:Number = mxy - y;
			
			alfa=Number(alfa>=0.001)*alfa;
			var tmp:Number=Number(alfa<=0.999);
			alfa=tmp*alfa+(1.0-tmp);
			
			alfa=Number(beta>=0.001)*alfa; 
			tmp=Number(beta<=0.999);
			beta=tmp*beta+(1.0-tmp);
			
			var mnyw:int = __cint(mny * stride);
			//var mxyw:int = mxy * stride;    
			 
			var iywx:Number = Memory.readUnsignedByte(__cint(imgPtr + mnyw+mnx));
			var iywxx:Number = Memory.readUnsignedByte(__cint(imgPtr + mnyw+mxx));
			
			val = (beta * (alfa * iywx + (1.0-alfa) *  iywxx) + (1.0-beta) * (alfa * iywx + (1.0-alfa) * iywxx));
		}
		
		public static function shiTomasiScore4x4(img_row:int, stride:int, dXX:int, dYY:int, dXY:int, math:*, score:int):void
		{
			var x:int, y:int, a:int, b:int, d:int, c:int;
			var row:int = __cint(img_row - 4*stride - 4);
			dXX = dYY = dXY = 0;
			var rw:int = row;
			a = Memory.readUnsignedByte(rw);
			b = Memory.readUnsignedByte(__cint(rw + stride));
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			row = __cint(row + stride);
			rw = row;
			a = Memory.readUnsignedByte(rw);
			b = Memory.readUnsignedByte(__cint(rw + stride));
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			row = __cint(row + stride);
			rw = row;
			a = Memory.readUnsignedByte(rw);
			b = Memory.readUnsignedByte(__cint(rw + stride));
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			row = __cint(row + stride);
			rw = row;
			a = Memory.readUnsignedByte(rw);
			b = Memory.readUnsignedByte(__cint(rw + stride));
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			row = __cint(row + stride);
			rw = row;
			a = Memory.readUnsignedByte(rw);
			b = Memory.readUnsignedByte(__cint(rw + stride));
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			row = __cint(row + stride);
			rw = row;
			a = Memory.readUnsignedByte(rw);
			b = Memory.readUnsignedByte(__cint(rw + stride));
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			row = __cint(row + stride);
			rw = row;
			a = Memory.readUnsignedByte(rw);
			b = Memory.readUnsignedByte(__cint(rw + stride));
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			row = __cint(row + stride);
			rw = row;
			a = Memory.readUnsignedByte(rw);
			b = Memory.readUnsignedByte(__cint(rw + stride));
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			row = __cint(row + stride);
			rw = row;
			a = Memory.readUnsignedByte(rw);
			b = Memory.readUnsignedByte(__cint(rw + stride));
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			__asm(IncLocalInt(rw));
			b = Memory.readUnsignedByte(rw);
			d = Memory.readUnsignedByte(__cint(rw+stride));
			a = __cint(d - a);
			c = __cint(b - c);
			x = __cint(a + c);
			y = __cint(a - c);
			a = b;
			c = d;
			dXX = __cint(dXX + x*x);
			dYY = __cint(dYY + y*y);
			dXY = __cint(dXY + x*y);
			row = __cint(row + stride);

			//dXX = dXX * 0.006172839506172839;
  			//dYY = dYY * 0.006172839506172839;
  			//dXY = dXY * 0.006172839506172839;
			//score = 0.5 * (dXX + dYY - sqrt( (dXX + dYY) * (dXX + dYY) - 4 * (dXX * dYY - dXY * dXY) ));
			//var ddx:Number = dXX + dYY;
			var ddx:int = __cint(dXX + dYY);
			//var sqrt:Number;
			__asm(__as3(math), __as3(ddx * ddx - 4.0 * (dXX * dYY - dXY * dXY)), CallProperty(__as3(Math.sqrt), 1), ConvertInt, SetLocal(dXX));
			score = __cint(ddx - dXX);
		}
		
		/*
		internal static function fillUCharPass(ptr:int, i:int, img:Vector.<uint>):void
		{
			__asm(
				GetLocal(img),
				GetLocal(i),
				GetProperty(AbcMultinameL(AbcNamespaceSet(AbcNamespace(NamespaceKind.PACKAGE, "")))),
				ConvertInt,
				GetLocal(ptr),
				SetByte,
				IncLocalInt(i),
				IncLocalInt(ptr)
			);
		}
		internal static function fillIntPass(ptr:int, i:int, img:Vector.<uint>):void
		{
			__asm(
				GetLocal(img),
				GetLocal(i),
				GetProperty(AbcMultinameL(AbcNamespaceSet(AbcNamespace(NamespaceKind.PACKAGE, "")))),
				ConvertInt,
				GetLocal(ptr),
				SetInt,
				IncLocalInt(i),
				GetLocal(ptr),
				PushByte(4),
				AddInt,
				SetLocal(ptr)
			);
		}
		*/
		internal static function pyrPass(row0:int, row1:int, out:int):void
		{
			__asm(
				GetLocal(row0),
				GetByte,
				IncLocalInt(row0),
				GetLocal(row0),
				GetByte,
				AddInt,				
				GetLocal(row1),
				GetByte,
				AddInt,
				IncLocalInt(row1),
				GetLocal(row1),
				GetByte,
				AddInt,
				PushByte(2),
				ShiftRight, 
				GetLocal( out ), 
				SetByte,
				IncLocalInt(out),
				IncLocalInt(row0),
				IncLocalInt(row1)
			);
		}
	}
}
