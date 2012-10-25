package ru.inspirit.image.edges
{
	import ru.inspirit.image.mem.MemImageMacro;
	import apparat.asm.IncLocalInt;
	import apparat.asm.__asm;
	import apparat.asm.__cint;
	import apparat.math.IntMath;
	import apparat.memory.Memory;
	import apparat.memory.memset;
	
	/**
	 * released under MIT License (X11)
	 * http://www.opensource.org/licenses/mit-license.php
	 * 
	 * This class provides a configurable implementation of the Canny edge
	 * detection algorithm. This classic algorithm has a number of shortcomings,
	 * but remains an effective tool in many scenarios.
	 * 
	 * @author Eugene Zatepyakin
	 * @see http://blog.inspirit.ru
	 * 
	 * @author Patrick Le Clec'h
	 * lots of speed up tips and tricks ;-) 
	 */
	public class CannyEdgeDetector
	{	
		protected var width:int;
		protected var height:int;
		protected var area:int;
		protected var _lowThreshold:Number;
		protected var _highThreshold:Number;
		
		public var gradXPtr:int;
		public var gradYPtr:int;
		public var magPtr:int;
		protected var histPtr:int;
		
		public function calcRequiredChunkSize(width:int, height:int):int
		{
			var size:int = (130050 << 2); // histogram space
			size += (width * height) << 2;
			size += (width * height) << 2;
			size += (width * height) << 2;
			size += (3 * (width + 2)) << 2;
			size += ((height + 2) * (width + 2)) << 2;
			size += (width * height) << 2;
			
			return IntMath.nextPow2(size);
		}
		
		public function setup(memOffset:int, width:int, height:int):void
		{
			this.width = width;
			this.height = height;
			this.area = width * height;
			
			gradXPtr = memOffset;
			gradYPtr = gradXPtr + (area << 2);
			magPtr = gradYPtr + (area << 2);
			histPtr = magPtr + (area << 2);
		}
		
		/**
		 * @param imgPtr	mem offset to image data (uchar)
		 * @param edgPtr	mem offset to edges data (int)
		 */
		public function detect(imgPtr:int, edgPtr:int, width:int, height:int):void
		{
			var w:int = width;
			var h:int = height;
			var a:int, b:int, outxp:int, outyp:int;
			var i:int, dx:int, dy:int;
			var stride4:int = w << 2;
			var magp:int;
			var maxMag:int = 0;
			var magn:int;
			var temp:int;
			var thresh_low:Number = this.lowThreshold;
			var thresh_high:Number = this.highThreshold;			
			var row:int;

		    // Sobel filter
		    var eh:int = __cint(h - 1);
			var ew:int = __cint(w - 1); 
			var y:int, x:int;

			var p:int = __cint( imgPtr + w );
			var pu:int = __cint( p - w );
			var pd:int = __cint( p + w );
			var qx:int = __cint( gradXPtr + stride4 );
			var qy:int = __cint( gradYPtr + stride4 );
			magp = __cint( magPtr + stride4 );
			// temporary data structures; use top rows of output, since
			// they are not filled in until the very end
			var t0:int = gradXPtr;
			var t1:int = gradYPtr;
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
					Memory.writeInt(__cint( b + a + (Memory.readUnsignedByte(_p)<<1) ), _t1);
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
				
				dx = __cint( (Memory.readInt(_t1+4) - Memory.readInt(_t1)) >> shift );
				dy = __cint( (a + Memory.readInt(_t0+4) + (a<<1)) >> shift);
				
				magn = __cint(dx*dx + dy*dy);	            
	            temp = int(magn>maxMag);
				maxMag = __cint(magn*temp+(1-temp)*maxMag);
	            
	            Memory.writeInt(dx, _qx);
	            Memory.writeInt(dy, _qy);
				Memory.writeInt(magn, magp);
				
				_qx = __cint(_qx + 4); _qy = __cint(_qy + 4);
				_t0 = __cint( _t0 + 4 ); _t1 = __cint( _t1 + 4 );
				magp = __cint(magp + 4);
				
				// convolve horizontal
				for(x = 1; x < ew; ++x)
				{				
					dx = __cint( (Memory.readInt(_t1+4) - Memory.readInt(_t1-4)) >> shift );
					dy = __cint( (Memory.readInt(_t0-4) + Memory.readInt(_t0+4)
											+ (Memory.readInt(_t0)<<1)) >> shift );
					magn = __cint(dx*dx + dy*dy);	            
		            temp = int(magn>maxMag);
					maxMag = __cint(magn*temp+(1-temp)*maxMag);
		            
		            Memory.writeInt(dx, _qx);
		            Memory.writeInt(dy, _qy);
					Memory.writeInt(magn, magp);
					
					_qx = __cint(_qx + 4); _qy = __cint(_qy + 4);
					_t0 = __cint(_t0 + 4); _t1 = __cint(_t1 + 4);
					magp = __cint(magp + 4);
				}
				
				a = Memory.readInt(_t0);
				
				dx = __cint( (Memory.readInt(_t1) - Memory.readInt(_t1-4)) >> shift );
				dy = __cint( (Memory.readInt(_t0-4) + a + (a<<1)) >> shift );
				magn = __cint(dx*dx + dy*dy);	            
	            temp = int(magn>maxMag);
				maxMag = __cint(magn*temp+(1-temp)*maxMag);
	            
	            Memory.writeInt(dx, _qx);
	            Memory.writeInt(dy, _qy);
				Memory.writeInt(magn, magp);
				
				magp = __cint(magp + 4);
				
				p = __cint(p + w);
				pu = __cint(pu + w);
				pd = __cint( pd + w );
				qx = __cint( qx + stride4 );
				qy = __cint( qy + stride4 );
			}
            //
			maxMag++;
			row = histPtr;
			magp = magPtr;
			var area:int = __cint(w * h);
			var numedges:int, highcount:int, maximum_mag:int, highthreshold:int, lowthreshold:int;
			
			memset( row, 0, maxMag << 2 );
			for (i = 0; i < area; ++i)
			{
				a = __cint(row + (Memory.readInt(magp) << 2));
				b = Memory.readInt(a);
				__asm(IncLocalInt(b));
				Memory.writeInt(b, a);
				magp = __cint(magp + 4);
			}
			
			row = __cint(histPtr + 4);
			maximum_mag = 0;
			for(i = 1, numedges = 0; i < maxMag; ++i)
			{
				a = Memory.readInt(row);
				temp = int(a!=0);
				maximum_mag = __cint(i*temp+(1-temp)*maximum_mag);
				numedges = __cint(numedges + a);
				row = __cint(row + 4);
			}
			
			highcount = numedges * thresh_high + 0.5;
			i = 1;
			numedges = Memory.readInt(histPtr + 4);
			row = __cint(histPtr + 8);
			b = __cint(maximum_mag-1);
			while( i < b && numedges < highcount )
			{
				__asm(IncLocalInt(i));
				a = Memory.readInt(row);
				numedges = __cint(numedges + a);
				row = __cint(row + 4);
			}
			
			highthreshold = i;
			lowthreshold = (highthreshold * thresh_low + 0.5);
			// 
		
			row = __cint( edgPtr + stride4 + 4 );
			outxp = __cint(gradXPtr + stride4 + 4);
			outyp = __cint(gradYPtr + stride4 + 4);
			magp = __cint(magPtr + stride4 + 4);
			maxMag = __cint( magPtr + ((w*(h - 1) + 1) << 2) );
			
			//var NO_EDGE_PIXEL:int = 0;
			//var DUMMY_PIXEL:int = 1;
			var EDGE_PIXEL:int = 0xFF;
			
			var reg:int;
			var o1:int, o2:int;
			var i1:int,i2:int,sx:int,sy:int,s:int, m1:int,m2:int,denom:int;
			var stride4p1:int = __cint( stride4 + 4);
			var stride4m1:int = __cint( stride4 - 4);
			var stackPtr:int = histPtr;
			
			memset( edgPtr, 0, stride4 );
			
			for (; magp < maxMag; )
			{
				Memory.writeInt( 0, row );
				row = __cint(row + 4);
				//
				var magn_max_x:int = __cint(magp + ((w - 2)<<2));
				for (; magp < magn_max_x;) 
				{
					magn = Memory.readInt(magp);
					if(magn < lowthreshold)
					{
						Memory.writeInt( 0, row );
					}
					else
					{
						// do NonMaxSuppress
						dx = Memory.readInt(outxp);
						dy = Memory.readInt(outyp);
						
						sx = __cint(1 - (int(dx<0) << 1)); //dx < 0?-1:1;
						sy = __cint(1 - (int(dy<0) << 1)); //dy < 0?-1:1;
						dx = __cint(dx * sx);
						dy = __cint(dy * sy);
						s = __cint(sx * sy);
						reg = magn;
						if (dy == 0)
						{
							m1 = Memory.readInt(__cint(magp + 4));
							m2 = Memory.readInt(__cint(magp - 4));
						} else if (dx == 0)
						{
							m1 = Memory.readInt(__cint(magp + stride4));
							m2 = Memory.readInt(__cint(magp - stride4));
						} 
						else 
						{
							var dy_lte_dx:int=int(dy <= dx);
							var dy_lte_dx_1:int=__cint(1-dy_lte_dx);
							var s_gtz:int=int(s>0);
							var s_gtz_1:int=__cint(1-s_gtz);
							
							o1 = __cint(s_gtz*( (dy_lte_dx<<2) + dy_lte_dx_1*stride4p1) + s_gtz_1*(dy_lte_dx*stride4m1+dy_lte_dx_1*stride4));
							o2 = __cint(s_gtz*( dy_lte_dx*stride4p1 + dy_lte_dx_1*stride4) + s_gtz_1*(dy_lte_dx_1*stride4m1-(dy_lte_dx<<2)));
							i1 = __cint(s_gtz*(dy_lte_dx*dy + dy_lte_dx_1*(dy - dx)) + s_gtz_1*(dy_lte_dx*(dx - dy)+dy_lte_dx_1*dx));
							
							denom = __cint(dy_lte_dx*dx+dy_lte_dx_1*dy);
							i2 = __cint(denom-i1);
							
							//
									
							m1 = __cint(Memory.readInt(magp + o1)*i2 + Memory.readInt(magp + o2)*i1);
							m2 = __cint(Memory.readInt(magp - o1)*i2 + Memory.readInt(magp - o2)*i1);
							reg = __cint(magn * denom);
							
						}
					
						// result check
						var chk:int=int(int(reg>=m1) & int(reg>=m2) & int(m1!=m2));
						var m_ge_h:int=__cint(chk*int(magn >= highthreshold));
						Memory.writeInt( __cint(chk * (m_ge_h*0xff+(1-m_ge_h))), row );

						Memory.writeInt(row, stackPtr);
						stackPtr = __cint(stackPtr + (m_ge_h<<2));
					}
					//
					magp = __cint(magp + 4);
					outxp = __cint(outxp + 4);
					outyp = __cint(outyp + 4);
					row = __cint(row + 4);
				}
				Memory.writeInt( 0, row );
				row = __cint(row + 4);
				
				magp = __cint(magp + 8);
				outxp = __cint(outxp + 8);
				outyp = __cint(outyp + 8);
			}
			
			// fill last row with zero
			for(i=0; i < w; ++i)
			{
				Memory.writeInt( 0, row );
				row = __cint(row + 4);
			}
			
			// simple path following
			i = histPtr;
			while (stackPtr > i) 
			{
				 stackPtr = __cint(stackPtr - 4);
				 row = Memory.readInt(stackPtr);
		
				row = __cint( row - stride4p1 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );

					Memory.writeInt(row, stackPtr);
					stackPtr = __cint(stackPtr + 4);
				}
				row = __cint( row + 4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stackPtr);
					stackPtr = __cint(stackPtr + 4);
				}
				row = __cint( row + 4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stackPtr);
					stackPtr = __cint(stackPtr + 4);
				}
				row = __cint( row + stride4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stackPtr);
					stackPtr = __cint(stackPtr + 4);
				}
				row = __cint( row - 8 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stackPtr);
					stackPtr = __cint(stackPtr + 4);
				}
				row = __cint( row + stride4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stackPtr);
					stackPtr = __cint(stackPtr + 4);
				}
				row = __cint( row + 4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stackPtr);
					stackPtr = __cint(stackPtr + 4);
				}
				row = __cint( row + 4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stackPtr);
					stackPtr = __cint(stackPtr + 4);
				}
			}
		}
		
		/**
		 * @param imgPtr	mem offset to image data (uchar)
		 * @param edgPtr	mem offset to edges data (int)
		 */
		public function detect2(imgPtr:int, edgPtr:int, width:int, height:int):void
		{
			var w:int = width;
			var h:int = height;
			var i:int, dx:int, dy:int;
			var stride4:int = w << 2;
			var row:int;
			var x:int = gradXPtr;
			var y:int = gradYPtr;

		    // Sobel filter
		    MemImageMacro.gradientSobel(imgPtr, x, y, w, h);
            
			
			//var NO_EDGE_PIXEL:int = 0;
			//var DUMMY_PIXEL:int = 1;
			var EDGE_PIXEL:int = 0xFF;
			var area4:int = __cint((w * h) << 2);
			var w2:int = __cint(w + 2);
			var h2:int = __cint(h + 2);
			var j:int;
			
			var thresh_low:int = this.lowThreshold + 0.5;
			var thresh_high:int = this.highThreshold + 0.5;
			
			var mbuf:int = __cint(gradYPtr + area4);
			var mbuf_size:int = __cint(3 * w2);
			var map:int = __cint(mbuf + (mbuf_size<<2));
			var stack:int = __cint(map + ((w2 * h2) << 2));
			var stack_top:int = stack;
			var stack_bottom:int = stack;
			
			row = mbuf;
			for(i = 0; i < mbuf_size; ++i)
			{
				Memory.writeInt(0, row);
				row = __cint(row + 4);
			}
			
			var rows0:int = __cint(mbuf + 4);
			var rows1:int = __cint(mbuf + (((w2) + 1) << 2) );
			var rows2:int = __cint(mbuf + ((2 * (w2) + 1) << 2) );
			
			var dxi:int = gradXPtr;
			var dyi:int = gradYPtr;
			
			row = rows1;
			for (i = 0; i < w; ++i)
			{
				Memory.writeInt(__cint( IntMath.abs(Memory.readInt(dxi)) + IntMath.abs(Memory.readInt(dyi)) ), row);
				dxi = __cint(dxi + 4);
				dyi = __cint(dyi + 4);
				row = __cint(row + 4);
			}
			
			row = map;
			for (i = 0; i < w2; ++i)
			{
				Memory.writeInt(0, row);
				row = __cint(row + 4);
			}
			
			var map_ptr:int = __cint(map + ((w2 + 1)<<2));
			var _dxi:int, _dyi:int;
			for (i = 1; i <= h; ++i)
			{
				if (i == h)
				{
					row = rows2;
					for (j = 0; j < w; ++j)
					{
						Memory.writeInt(0, row);
						row = __cint(row + 4);
					}
				}else{
					row = rows2;
					_dxi = dxi;
					_dyi = dyi;
					for (j = 0; j < w; ++j)
					{
						Memory.writeInt(__cint( IntMath.abs(Memory.readInt(_dxi)) + IntMath.abs(Memory.readInt(_dyi)) ), row);
						_dxi = __cint(_dxi + 4);
						_dyi = __cint(_dyi + 4);
						row = __cint(row + 4);
					}
				}
				var _dx:int = __cint(dxi - stride4);
				var _dy:int = __cint(dyi - stride4);
				Memory.writeInt(0, __cint(map_ptr - 4));
				var suppress:int = 0;
				
				for (j = 0; j < w; ++j)
				{
					var f:int = Memory.readInt(__cint( rows1 + (j<<2) ));
					if (f > thresh_low)
					{
						dx = Memory.readInt(__cint(_dx + (j<<2)));
						dy = Memory.readInt(__cint(_dy + (j<<2)));
						x = IntMath.abs(dx);
						y = IntMath.abs(dy);
						var s:int = dx ^ dy;
						/* x * tan(22.5) */
						var tg22x:int = x * int(0.4142135623730950488016887242097 * (1 << 15) + 0.5);
						/* x * tan(67.5) == 2 * x + x * tan(22.5) */
						var tg67x:int = __cint(tg22x + ((x + x) << 15));
						y <<= 15;
						// sometimes, we end up with same f in integer domain, 
						// for that case, we will take the first occurrence
						// suppressing the second with flag
						if (y < tg22x)
						{
							if (f > Memory.readInt(__cint( rows1 + ((j - 1)<<2) )) && f >= Memory.readInt(__cint( rows1 + ((j + 1)<<2) )))
							{
								if (f > thresh_high && !suppress && Memory.readInt(__cint( map_ptr + ((j - w2)<<2) )) != EDGE_PIXEL)
								{
									row = __cint( map_ptr + (j<<2) );
									Memory.writeInt(EDGE_PIXEL, row);
									suppress = 1;
									Memory.writeInt(row, stack_top);
									stack_top = __cint(stack_top + 4);
								} else {
									Memory.writeInt(1, __cint( map_ptr + (j<<2) ));
								}
								continue;
							}
						} else if (y > tg67x) 
						{
							if (f > Memory.readInt(__cint( rows0 + (j<<2) )) && f >= Memory.readInt(__cint( rows2 + (j<<2) )))
							{
								if (f > thresh_high && !suppress && Memory.readInt(__cint( map_ptr + ((j - w2)<<2) )) != EDGE_PIXEL)
								{
									row = __cint( map_ptr + (j<<2) );
									Memory.writeInt(EDGE_PIXEL, row);
									suppress = 1;
									Memory.writeInt(row, stack_top);
									stack_top = __cint(stack_top + 4);
								} else {
									Memory.writeInt(1, __cint( map_ptr + (j<<2) ));
								}
								continue;
							}
						} else {
							s = s < 0 ? -1 : 1;
							if (f > Memory.readInt(__cint( rows0 + ((j - s)<<2) )) && f > Memory.readInt(__cint( rows2 + ((j + s)<<2) )))
							{
								if (f > thresh_high && !suppress && Memory.readInt(__cint( map_ptr + ((j - w2)<<2) )) != EDGE_PIXEL)
								{
									row = __cint( map_ptr + (j<<2) );
									Memory.writeInt(EDGE_PIXEL, row);
									suppress = 1;
									Memory.writeInt(row, stack_top);
									stack_top = __cint(stack_top + 4);
								} else {
									Memory.writeInt(1, __cint( map_ptr + (j<<2) ));
								}
								continue;
							}
						}
					}
					Memory.writeInt(0, __cint(map_ptr + (j<<2)));
					suppress = 0;
				}
				Memory.writeInt(0, __cint(map_ptr + stride4));
				map_ptr = __cint(map_ptr + (w2<<2));
				dxi = __cint(dxi + stride4);
				dyi = __cint(dyi + stride4);
				row = rows0;
				rows0 = rows1;
				rows1 = rows2;
				rows2 = row;
			}
			
			// fill last row with zero
			row = __cint(map_ptr - ((w2 - 1)<<2));
			for(i=0; i < w2; ++i)
			{
				Memory.writeInt( 0, row );
				row = __cint(row + 4);
			}
			
			// simple path following
			var stride4p1:int = __cint((w2 + 1) << 2);
			var w24:int = __cint(w2 << 2);
			
			while (stack_top > stack_bottom)
			{
				 stack_top = __cint(stack_top - 4);
				 row = Memory.readInt(stack_top);
		
				row = __cint( row - stride4p1 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );

					Memory.writeInt(row, stack_top);
					stack_top = __cint(stack_top + 4);
				}
				row = __cint( row + 4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stack_top);
					stack_top = __cint(stack_top + 4);
				}
				row = __cint( row + 4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stack_top);
					stack_top = __cint(stack_top + 4);
				}
				row = __cint( row + w24 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stack_top);
					stack_top = __cint(stack_top + 4);
				}
				row = __cint( row - 8 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stack_top);
					stack_top = __cint(stack_top + 4);
				}
				row = __cint( row + w24 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stack_top);
					stack_top = __cint(stack_top + 4);
				}
				row = __cint( row + 4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stack_top);
					stack_top = __cint(stack_top + 4);
				}
				row = __cint( row + 4 );
				if(Memory.readInt(row) == 1)
				{
					Memory.writeInt( EDGE_PIXEL, row );
					Memory.writeInt(row, stack_top);
					stack_top = __cint(stack_top + 4);
				}
			}
			
			map_ptr = __cint(map + ((w2 + 1)<<2));
			for(i = 0; i < h; ++i)
			{
				row = map_ptr;
				for(j = 0; j < w; ++j)
				{
					Memory.writeInt(Memory.readInt(row), edgPtr);
					edgPtr = __cint(edgPtr + 4);
					row = __cint(row + 4);
				}
				map_ptr = __cint(map_ptr + w24);
			}
		}
		
		public function set lowThreshold(value:Number):void
		{
			_lowThreshold = value;
		}
		public function get lowThreshold():Number
		{
			return _lowThreshold;
		}

		public function set highThreshold(value:Number):void
		{
			_highThreshold = value;
		}
		public function get highThreshold():Number
		{
			return _highThreshold;
		}
	}
}
