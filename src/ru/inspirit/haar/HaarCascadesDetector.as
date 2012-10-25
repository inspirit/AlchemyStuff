package ru.inspirit.haar 
{
	import apparat.asm.*;
	import apparat.math.FastMath;
	import apparat.math.IntMath;
	import apparat.memory.Memory;

	import flash.display.BitmapData;
	import flash.geom.Rectangle;

	/**
	 * @author Eugene Zatepyakin
	 */
	public final class HaarCascadesDetector 
	{		
		protected var cascadeWidth:int;
		protected var cascadeHeight:int;
		
		protected var imageWidth:int;
		protected var imageHeight:int;
		
		protected var treeBasedCascades:Boolean = false;
		
		protected var stages:HaarStage;
		protected var featureRects:HaarFeatureRect;
		
		protected var stagesCount:int;
		protected var featuresCount:int;
		protected var featureRectsCount:int;
		protected var treesCount:int;
		
		protected var bmp:BitmapData;
		protected var rect:Rectangle;
		
		protected var memPtr:int;
		protected var integralOffset:int;
		protected var sqOffset:int;
		protected var edgeOffset:int;
		
		public var baseScale:Number = 2;
		public var scaleIncrement:Number = 1.15;
		public var increment:Number = 0.05;
		public var edgesPtr:int = -1;
		public var otherDetector:HaarCascadesDetector = null;
		public var bounds:Rectangle = null;
		public var result:Vector.<Rectangle>;
		public var resultsCount:int;
		public var maxCandidatesToBreak:int = -1;
		
		protected var stepScaleIncrement:Number = scaleIncrement;
		protected var stepIncrement:Number = increment;
		protected var stepBounds:Rectangle = bounds;
		protected var stepIntOff:int;
		protected var stepSqOff:int;
		protected var stepEdgeOff:int;
		protected var useEdges:Boolean;
		protected var minScaleX:int;
		protected var minScaleY:int;
		protected var stepIterCount:int;
		
		public var edgesDensity:Number = 0.07 * 255;
		
		public var state:int = -1;
		public var numSteps:int = 2;
		
		public var onImageDataUpdate:Function;
		
		public function setup(memOffset:int, source:BitmapData, cascadeData:XML, treeBased:Boolean):void
		{
			memPtr = memOffset;
			image = source;
			setupCascadeData(cascadeData, treeBased);
		}
		
		public function nextFrame():void
		{
			state = ++state % numSteps;

			if (state == 0)
			{
				if(null!=onImageDataUpdate)
				{
					onImageDataUpdate();
				}
				
				prepareData();
			}
			
			detectStep();

			if (maxCandidatesToBreak > -1 && resultsCount >= maxCandidatesToBreak)
			{
				state = numSteps - 1;
			}
		}
		
		protected function prepareData():void
		{
			var intOff:int = integralOffset;
			var sqOff:int = sqOffset;
			var edgeOff:int = edgeOffset;
			var width:int = imageWidth;
			var height:int = imageHeight;
			var s1:int = 0;
			var s2:int = 0;
			var s3:int = 0;
			var c:int;
			
			var j:int, i:int;
			var ind:int;
			var ind0:int;
			
			useEdges = edgesPtr > -1;
			
			if(null == otherDetector)
			{
				
				var data:Vector.<uint> = bmp.getVector(rect);
				
				if(useEdges)
				{	
					var i4:int = 0;
					for(i = 0; i < width; ++i)
					{
						c = (data[i] & 0xFF);
						s1 = __cint(s1 + c);
						s2 = __cint(s2 + c * c);
						s3 = __cint(s3 + (Memory.readInt(edgesPtr + i4) & 0xFF));
						
						Memory.writeInt(s1, __cint(intOff + i4));
						Memory.writeInt(s2, __cint(sqOff + i4));
						Memory.writeInt(s3, __cint(edgeOff + i4));
						i4 = __cint(i4 + 4);
					}
					
					ind = width;
					ind0 = 0;
					
					for(j = 1; j < height; ++j)
					{
						s1 = 0;
						s2 = 0;
						s3 = 0;
						for(i = 0; i < width; )
						{
							c = (data[ind] & 0xFF);
							s1 = __cint(s1 + c);
							s2 = __cint(s2 + c * c);
							s3 = __cint(s3 + (Memory.readInt(edgesPtr + i4) & 0xFF));
							
							Memory.writeInt(__cint(Memory.readInt(intOff + ind0) + s1), __cint(intOff+ i4));
							Memory.writeInt(__cint(Memory.readInt(sqOff + ind0) + s2), __cint(sqOff + i4));
							Memory.writeInt(__cint(Memory.readInt(edgeOff + ind0) + s3), __cint(edgeOff + i4));
							//
							__asm(IncLocalInt(i), IncLocalInt(ind));
							i4 = __cint(i4 + 4);
							ind0 = __cint(ind0 + 4);
						}
					}
				}
				else
				{
					i4 = 0;
					for(i = 0; i < width; ++i)
					{
						c = (data[i] & 0xFF);
						s1 = __cint(s1 + c);
						s2 = __cint(s2 + c * c);
						
						Memory.writeInt(s1, __cint(intOff + i4));
						Memory.writeInt(s2, __cint(sqOff + i4));
						i4 = __cint(i4 + 4);
					}
					
					ind = width;
					ind0 = 0;
					
					for(j = 1; j < height; ++j)
					{
						s1 = 0;
						s2 = 0;
						for(i = 0; i < width; )
						{
							c = (data[ind] & 0xFF);
							s1 = __cint(s1 + c);
							s2 = __cint(s2 + c * c);
							
							Memory.writeInt(__cint(Memory.readInt(intOff + ind0) + s1), __cint(intOff+ i4));
							Memory.writeInt(__cint(Memory.readInt(sqOff + ind0) + s2), __cint(sqOff + i4));
							//
							__asm(IncLocalInt(i), IncLocalInt(ind));
							i4 = __cint(i4 + 4);
							ind0 = __cint(ind0 + 4);
						}
					}
				}
			}
			else 
			{
				intOff = otherDetector.integralImageOffset;
				sqOff = otherDetector.integralSquareImageOffset;
				edgeOff = otherDetector.integralEdgeImageOffset;
			}
			
			stepIntOff = intOff;
			stepSqOff = sqOff;
			stepEdgeOff = edgeOff;
			
			if(bounds == null)
			{
				bounds = rect;
			}

			stepBounds = bounds;
			stepIncrement = increment;
			stepScaleIncrement = scaleIncrement;
			//
			minScaleX = cascadeWidth * baseScale;
			minScaleY = cascadeHeight * baseScale;
			//
			var numIts:int = 0;
			var msx:int = minScaleX;
			var msy:int = minScaleY;
			while(msx <= bounds.width && msy <= bounds.height
					&& (msx >= cascadeWidth && msy >= cascadeHeight))
			{
				numIts++;
				msx *= scaleIncrement;
				msy *= scaleIncrement;
			}
			
			stepIterCount = (numIts / numSteps) + 1;
			//
			resultsCount = 0;
			result = new Vector.<Rectangle>();
		}
		
		protected function detectStep():void
		{
			var intOff:int = stepIntOff;
			var sqOff:int = stepSqOff;
			var edgeOff:int = stepEdgeOff;
			
			var s1:int = 0;
			var s2:int = 0;
			
			var width:int = imageWidth;
			
			var j:int, i:int;
			var ind:int;
			var ind0:int;
			
			var maxSizeX:int = stepBounds.width;
			var maxSizeY:int = stepBounds.height;
			
			var sx:int;
			var sy:int;
			var sw:int = maxSizeX;
			var sh:int = maxSizeY;
			var ex:int;
			var ey:int;
			var stepX:int;
			var stepY:int;
			
			var rectOff:int;
			var c1:int, r1:int, c2:int, r2:int;
			
			var curWinSizeX:int;
			var curWinSizeY:int;
			var curScaleX:Number;
			var curScaleY:Number;
			var curWinArea1:Number;
			var curWinArea2:Number;
			var mean:Number;
			var vnorm:Number;
			var pass:Boolean;
			var sum:Number;
			var rect_sum:Number;
			var edgeThreshold:Number;
			
			var st:HaarStage;
			var ft:HaarFeature;
            var rc:HaarFeatureRect;
            
            var iter:int = 0;
			
			var math:*;
			__asm(__as3(Math), SetLocal(math));
			
			if(!treeBasedCascades)
			{
			
			while( iter < stepIterCount && (minScaleX <= maxSizeX && minScaleY <= maxSizeY)
										&& (minScaleX >= cascadeWidth && minScaleY >= cascadeHeight) ) 
			{
				curWinSizeX = minScaleX;
				curWinSizeY = minScaleY;
				curScaleX = minScaleX / cascadeWidth;
				curScaleY = minScaleY / cascadeHeight;
				curWinArea1 = 1.0 / (minScaleX * minScaleY * 255);
				curWinArea2 = 1.0 / (minScaleX * minScaleY * 65025);
				stepX = (curWinSizeX * stepIncrement + 0.5);
				stepY = (curWinSizeY * stepIncrement + 0.5);
				edgeThreshold = curWinSizeX * curWinSizeY * edgesDensity;
				
				// rescale rectangles
				
				rc = featureRects;
				while(null != rc)
				{
					c1 = rc.x * curScaleX + 0.5;
					r1 = rc.y * curScaleY + 0.5;
					c2 = rc.w * curScaleX + 0.5;
					r2 = rc.h * curScaleY + 0.5;
					rc.n1 = __cint((r1 * width + c1) << 2);
					rc.n2 = __cint(rc.n1 + (c2 << 2));
					rc.n3 = __cint(((r1 + r2) * width + c1) << 2);
					rc.n4 = __cint(rc.n3 + (c2 << 2));
					rc = rc.nextChainRect;
				}
				
				sy = stepBounds.y;
				ey = __cint(sy + sh - curWinSizeY);
				while(sy < ey)
				{
					sx = stepBounds.x;
					ex = __cint(sx + sw - curWinSizeX);
					s1 = __cint(sy * width);
					s2 = __cint((sy + curWinSizeY) * width);
					rectOff = __cint(intOff + ((sy * width + sx)<<2));
					while(sx < ex)
					{
						// Check edges if needed
						
						if (useEdges)
						{
							if( __cint(Memory.readInt( edgeOff+((s1 + sx)<<2) )
                        				- Memory.readInt( edgeOff+((s1 + sx+curWinSizeX)<<2) )
                        				- Memory.readInt( edgeOff+((s2 + sx)<<2) ) 
                        				+ Memory.readInt( edgeOff+((s2 + sx+curWinSizeX)<<2))) < edgeThreshold ) 
                        				{
                        					// skip it
                        					sx = __cint(sx + stepX);
											rectOff = __cint( rectOff + (stepX << 2));
											continue;
                        				}
						}
						
						 
						// Run Cascade
						
						mean = __cint(Memory.readInt( intOff+(i=(s1 + sx)<<2) )
                        				- Memory.readInt( intOff+(j=(s1 + sx+curWinSizeX)<<2) )
                        				- Memory.readInt( intOff+(ind=(s2 + sx)<<2) ) 
                        				+ Memory.readInt( intOff+(ind0=(s2 + sx+curWinSizeX)<<2) )) * curWinArea1;
                        
                        vnorm = __cint(Memory.readInt( sqOff + i )
                        				- Memory.readInt( sqOff + j )
                        				- Memory.readInt( sqOff + ind ) 
                        				+ Memory.readInt( sqOff + ind0 )) * curWinArea2;
                        				
						/*vnorm = (mean * mean) - vnorm;
						if(vnorm < 0) vnorm = -vnorm;						
						vnorm = FastMath.sqrt2(vnorm, 0);*/
						vnorm = vnorm - (mean * mean);
						//vnorm = vnorm > 0 ? FastMath.sqrt2(vnorm, 0) : 1.0;
						if (vnorm > 0)
						{
							__asm(__as3(math), __as3(vnorm), CallProperty(__as3(Math.sqrt), 1), SetLocal(vnorm));
						}
						else
						{
							vnorm = 1.0;
						}
                        
                        pass = true;
                        st = stages;
						
						while(null != st)
						{
							sum = 0;
							ft = st.features;
							while(null != ft)
							{
								rect_sum = 0;

								rc = ft.hfr;
								i = 0;
								while(null != rc)
								{
									rect_sum +=
											 __cint(Memory.readInt( (rc.n1 + rectOff) )
											- Memory.readInt( (rc.n2 + rectOff) )
											- Memory.readInt( (rc.n3 + rectOff) )
											+ Memory.readInt( (rc.n4 + rectOff) )
											) * rc.weight;

									rc = rc.nextRect;
								}
								
								if(rect_sum*curWinArea1 < ft.threshold * vnorm) 
								{
									sum += ft.leftVal;
								}
								else
								{
									sum += ft.rightVal;
								}
								
								ft = ft.nextFeature;
							}
							
							if(sum < st.threshold) 
							{
								pass = false;
								break;
							}
							
							st = st.nextStage;
						}
						
						if(pass)
						{
							result[resultsCount] = new Rectangle(sx, sy, curWinSizeX, curWinSizeY);
							resultsCount++;
							if (maxCandidatesToBreak > -1 && maxCandidatesToBreak == resultsCount) return;
						}
						
						sx = __cint(sx + stepX);
						rectOff = __cint(rectOff + (stepX << 2));
					}
					sy = __cint(sy + stepY);
				}
				minScaleX *= stepScaleIncrement;
				minScaleY *= stepScaleIncrement;
				iter++;
			}
			
			}
			else // TREE BASED DETECTION
			{
				var tr:HaarTree;
				
				while( iter < stepIterCount && (minScaleX <= maxSizeX && minScaleY <= maxSizeY)
										&& (minScaleX >= cascadeWidth && minScaleY >= cascadeHeight) )  
				{
					curWinSizeX = minScaleX;
					curWinSizeY = minScaleY;
					curScaleX = minScaleX / cascadeWidth;
					curScaleY = minScaleY / cascadeHeight;
					curWinArea1 = 1.0 / (minScaleX * minScaleY * 255);
					curWinArea2 = 1.0 / (minScaleX * minScaleY * 65025);
					stepX = (curWinSizeX * stepIncrement + 0.5);
					stepY = (curWinSizeY * stepIncrement + 0.5);
					edgeThreshold = curWinSizeX * curWinSizeY * edgesDensity;
					
					// rescale rectangles
					
					rc = featureRects;
					while(null != rc)
					{
						c1 = rc.x * curScaleX + 0.5;
						r1 = rc.y * curScaleY + 0.5;
						c2 = rc.w * curScaleX + 0.5;
						r2 = rc.h * curScaleY + 0.5;
						rc.n1 = __cint((r1 * width + c1) << 2);
						rc.n2 = __cint(rc.n1 + (c2 << 2));
						rc.n3 = __cint(((r1 + r2) * width + c1) << 2);
						rc.n4 = __cint(rc.n3 + (c2 << 2));
						rc = rc.nextChainRect;
					}
					
					sy = stepBounds.y;
					ey = __cint(sy + sh - curWinSizeY);
					while(sy < ey)
					{
						sx = stepBounds.x;
						ex = __cint(sx + sw - curWinSizeX);
						s1 = __cint(sy * width);
						s2 = __cint((sy + curWinSizeY) * width);
						rectOff = __cint(intOff + ((sy * width + sx)<<2));
						while(sx < ex)
						{
							// Check edges if needed
						
							if (useEdges)
							{
								if( __cint(Memory.readInt( edgeOff+((s1 + sx)<<2) )
	                        				- Memory.readInt( edgeOff+((s1 + sx+curWinSizeX)<<2) )
	                        				- Memory.readInt( edgeOff+((s2 + sx)<<2) ) 
	                        				+ Memory.readInt( edgeOff+((s2 + sx+curWinSizeX)<<2))) < edgeThreshold ) 
	                        				{
	                        					// skip it
	                        					sx = __cint(sx + stepX);
												rectOff = __cint( rectOff + (stepX << 2));
												continue;
	                        				}
							}
							
							// Run Cascade
							
							mean = __cint(Memory.readInt( intOff+(i=(s1 + sx)<<2) )
	                        				- Memory.readInt( intOff+(j=(s1 + sx+curWinSizeX)<<2) )
	                        				- Memory.readInt( intOff+(ind=(s2 + sx)<<2) ) 
	                        				+ Memory.readInt( intOff+(ind0=(s2 + sx+curWinSizeX)<<2) )) * curWinArea1;
	                        
	                        vnorm = __cint(Memory.readInt( sqOff + i )
	                        				- Memory.readInt( sqOff + j )
	                        				- Memory.readInt( sqOff + ind ) 
	                        				+ Memory.readInt( sqOff + ind0 )) * curWinArea2;
	                        				
							/*vnorm = (mean * mean) - vnorm;
							if(vnorm < 0) vnorm = -vnorm;
							vnorm = FastMath.sqrt2(vnorm, 0);*/
							vnorm = vnorm - (mean * mean);
							//vnorm = vnorm > 0 ? FastMath.sqrt2(vnorm, 0) : 1.0;
							if (vnorm > 0)
							{
								__asm(__as3(math), __as3(vnorm), CallProperty(__as3(Math.sqrt), 1), SetLocal(vnorm));
							}
							else
							{
								vnorm = 1.0;
							}
	                        
	                        pass = true;	                        
							st = stages;
							
							while( null != st)
							{
								sum = 0;
								tr = st.trees;
								
								while( null != tr )
								{
									ft = tr.features;
									
									while( null != ft )
									{									
										rect_sum = 0;	
										rc = ft.hfr;
										
										while( null != rc )
										{
											rect_sum +=
													 __cint(Memory.readInt( (rc.n1 + rectOff) )
													- Memory.readInt( (rc.n2 + rectOff) )
													- Memory.readInt( (rc.n3 + rectOff) )
													+ Memory.readInt( (rc.n4 + rectOff) )
													) * rc.weight;

											rc = rc.nextRect;
										}
										
										if(rect_sum*curWinArea1 < ft.threshold * vnorm) 
										{
											sum += ft.leftVal;
											ft = ft.leftNode;
										}
										else
										{
											sum += ft.rightVal;
											ft = ft.rightNode;
										}
									}

									tr = tr.nextTree;
								}
								
								if(sum < st.threshold) 
								{
									pass = false;
									break;
								}

								st = st.nextStage;
							}
							
							if(pass)
							{
								result[resultsCount] = new Rectangle(sx, sy, curWinSizeX, curWinSizeY);
								resultsCount++;
								if (maxCandidatesToBreak > -1 && maxCandidatesToBreak == resultsCount) return;
							}
							
							sx = __cint(sx + stepX);
							rectOff = __cint(rectOff + (stepX << 2));
						}
						sy = __cint(sy + stepY);
					}
					minScaleX *= stepScaleIncrement;
					minScaleY *= stepScaleIncrement;
					iter++;
				}
			}
		}
		
		public function detect(bounds:Rectangle = null, baseScale:Number = 2, scaleIncrement:Number = 1.25, increment:Number = 0.1, edgesPtr:int = -1, otherDetector:HaarCascadesDetector = null):Vector.<Rectangle>
		{			
			// Integral Data
			
			var intOff:int = integralOffset;
			var sqOff:int = sqOffset;
			var edgeOff:int = edgeOffset;
			var width:int = imageWidth;
			var height:int = imageHeight;
			var s1:int = 0;
			var s2:int = 0;
			var s3:int = 0;
			var c:int;
			
			var j:int, i:int;
			var ind:int;
			var ind0:int;
			
			var locUseEdges:Boolean = edgesPtr > -1;
			
			if(null == otherDetector)
			{
				
				var data:Vector.<uint> = bmp.getVector(rect);
				
				if(locUseEdges)
				{					
					var i4:int = 0;
					for(i = 0; i < width; ++i)
					{
						c = (data[i] & 0xFF);
						s1 = __cint(s1 + c);
						s2 = __cint(s2 + c * c);
						s3 = __cint(s3 + (Memory.readInt(edgesPtr + i4) & 0xFF));
						
						Memory.writeInt(s1, __cint(intOff + i4));
						Memory.writeInt(s2, __cint(sqOff + i4));
						Memory.writeInt(s3, __cint(edgeOff + i4));
						i4 = __cint(i4 + 4);
					}
					
					ind = width;
					ind0 = 0;
					
					for(j = 1; j < height; ++j)
					{
						s1 = 0;
						s2 = 0;
						s3 = 0;
						for(i = 0; i < width; )
						{
							c = (data[ind] & 0xFF);
							s1 = __cint(s1 + c);
							s2 = __cint(s2 + c * c);
							s3 = __cint(s3 + (Memory.readInt(edgesPtr + i4) & 0xFF));
							
							Memory.writeInt(__cint(Memory.readInt(intOff + ind0) + s1), __cint(intOff+ i4));
							Memory.writeInt(__cint(Memory.readInt(sqOff + ind0) + s2), __cint(sqOff + i4));
							Memory.writeInt(__cint(Memory.readInt(edgeOff + ind0) + s3), __cint(edgeOff + i4));
							//
							__asm(IncLocalInt(i), IncLocalInt(ind));
							i4 = __cint(i4 + 4);
							ind0 = __cint(ind0 + 4);
						}
					}
				}
				else
				{
					i4 = 0;
					for(i = 0; i < width; ++i)
					{
						c = (data[i] & 0xFF);
						s1 = __cint(s1 + c);
						s2 = __cint(s2 + c * c);
						
						Memory.writeInt(s1, __cint(intOff + i4));
						Memory.writeInt(s2, __cint(sqOff + i4));
						i4 = __cint(i4 + 4);
					}
					
					ind = width;
					ind0 = 0;
					
					for(j = 1; j < height; ++j)
					{
						s1 = 0;
						s2 = 0;
						for(i = 0; i < width; )
						{
							c = (data[ind] & 0xFF);
							s1 = __cint(s1 + c);
							s2 = __cint(s2 + c * c);
							
							Memory.writeInt(__cint(Memory.readInt(intOff + ind0) + s1), __cint(intOff+ i4));
							Memory.writeInt(__cint(Memory.readInt(sqOff + ind0) + s2), __cint(sqOff + i4));
							//
							__asm(IncLocalInt(i), IncLocalInt(ind));
							i4 = __cint(i4 + 4);
							ind0 = __cint(ind0 + 4);
						}
					}
				}
			}
			else 
			{
				intOff = otherDetector.integralImageOffset;
				sqOff = otherDetector.integralSquareImageOffset;
				edgeOff = otherDetector.integralEdgeImageOffset;
				//locUseEdges = otherDetector.edgesPtr > -1;
			}
			//
			
			var rn:int = 0;
			var result:Vector.<Rectangle> = new Vector.<Rectangle>();
			
            var st:HaarStage;
			var ft:HaarFeature;
			var rc:HaarFeatureRect;
			
			if(bounds == null)
			{
				bounds = rect;
			}
			
			//
			var minScaleX:int = cascadeWidth * baseScale;
			var minScaleY:int = cascadeHeight * baseScale;
			var maxSizeX:int = bounds.width;
			var maxSizeY:int = bounds.height;
			
			var sx:int;
			var sy:int;
			var sw:int = bounds.width;
			var sh:int = bounds.height;
			var ex:int;
			var ey:int;
			var stepX:int;
			var stepY:int;
			
			var rectOff:int;
			var c1:int, r1:int, c2:int, r2:int;
			
			var curWinSizeX:int;
			var curWinSizeY:int;
			var curScaleX:Number;
			var curScaleY:Number;
			var curWinArea1:Number;
			var curWinArea2:Number;
			var mean:Number;
			var vnorm:Number;
			var pass:Boolean;
			var sum:Number;
			var rect_sum:Number;
			var edgeThreshold:Number;
			
			var math:*;
			__asm(__as3(Math), SetLocal(math));
			
			if(!treeBasedCascades)
			{
			
			while((minScaleX <= maxSizeX && minScaleY <= maxSizeY)
										&& (minScaleX >= cascadeWidth && minScaleY >= cascadeHeight)) 
			{
				curWinSizeX = minScaleX;
				curWinSizeY = minScaleY;
				curScaleX = minScaleX / cascadeWidth;
				curScaleY = minScaleY / cascadeHeight;
				curWinArea1 = 1.0 / (minScaleX * minScaleY * 255);
				curWinArea2 = 1.0 / (minScaleX * minScaleY * 65025);
				stepX = (curWinSizeX * increment + 0.5);
				stepY = (curWinSizeY * increment + 0.5);
				edgeThreshold = curWinSizeX * curWinSizeY * edgesDensity;
				
				// rescale rectangles
				
				rc = featureRects;
				while(null != rc)
				{
					c1 = rc.x * curScaleX + 0.5;
					r1 = rc.y * curScaleY + 0.5;
					c2 = rc.w * curScaleX + 0.5;
					r2 = rc.h * curScaleY + 0.5;
					rc.n1 = __cint((r1 * width + c1) << 2);
					rc.n2 = __cint(rc.n1 + (c2 << 2));
					rc.n3 = __cint(((r1 + r2) * width + c1) << 2);
					rc.n4 = __cint(rc.n3 + (c2 << 2));
					rc = rc.nextChainRect;
				}
				
				sy = bounds.y;
				ey = __cint(sy + sh - curWinSizeY);
				while(sy < ey)
				{
					sx = bounds.x;
					ex = __cint(sx + sw - curWinSizeX);
					s1 = __cint(sy * width);
					s2 = __cint((sy + curWinSizeY) * width);
					rectOff = __cint(intOff + ((sy * width + sx)<<2));
					while(sx < ex)
					{
						// Check edges if needed
						
						if (locUseEdges)
						{
							if( __cint(Memory.readInt( edgeOff+((s1 + sx)<<2) )
                        				- Memory.readInt( edgeOff+((s1 + sx+curWinSizeX)<<2) )
                        				- Memory.readInt( edgeOff+((s2 + sx)<<2) ) 
                        				+ Memory.readInt( edgeOff+((s2 + sx+curWinSizeX)<<2))) < edgeThreshold ) 
                        				{
                        					// skip it
                        					sx = __cint(sx + stepX);
											rectOff = __cint(rectOff + (stepX << 2));
											continue;
                        				}
						}
						
						 
						// Run Cascade
						
						mean = __cint(Memory.readInt( intOff+(i=(s1 + sx)<<2) )
                        				- Memory.readInt( intOff+(j=(s1 + sx+curWinSizeX)<<2) )
                        				- Memory.readInt( intOff+(ind=(s2 + sx)<<2) ) 
                        				+ Memory.readInt( intOff+(ind0=(s2 + sx+curWinSizeX)<<2) )) * curWinArea1;
                        
                        vnorm = __cint(Memory.readInt( sqOff + i )
                        				- Memory.readInt( sqOff + j )
                        				- Memory.readInt( sqOff + ind ) 
                        				+ Memory.readInt( sqOff + ind0 )) * curWinArea2;
                        				
						/*vnorm = (mean * mean) - vnorm;
						if(vnorm < 0) vnorm = -vnorm;						
						vnorm = FastMath.sqrt2(vnorm, 0);*/
						vnorm = vnorm - (mean * mean);
						//vnorm = vnorm > 0 ? FastMath.sqrt2(vnorm, 0) : 1.0;
						if (vnorm > 0)
						{
							__asm(__as3(math), __as3(vnorm), CallProperty(__as3(Math.sqrt), 1), SetLocal(vnorm));
						}
						else
						{
							vnorm = 1.0;
						}
                        
                        pass = true;						
						st = stages;
						
						while(null != st)
						{
							sum = 0;
							ft = st.features;
							
							while(null != ft)
							{
								rect_sum = 0;

								rc = ft.hfr;
								
								while(null != rc)
								{
									rect_sum +=
											 __cint(Memory.readInt( (rc.n1 + rectOff) )
											- Memory.readInt( (rc.n2 + rectOff) )
											- Memory.readInt( (rc.n3 + rectOff) )
											+ Memory.readInt( (rc.n4 + rectOff) )
											) * rc.weight;

									rc = rc.nextRect;
								}
								
								if(rect_sum*curWinArea1 < ft.threshold * vnorm) 
								{
									sum += ft.leftVal;
								}
								else
								{
									sum += ft.rightVal;
								}
								
								ft = ft.nextFeature;
							}
							
							if(sum < st.threshold) 
							{
								pass = false;
								break;
							}
							
							st = st.nextStage;
						}
						
						if(pass)
						{
							result[rn] = new Rectangle(sx, sy, curWinSizeX, curWinSizeY);
							__asm(IncLocalInt(rn));
							if (maxCandidatesToBreak > -1 && maxCandidatesToBreak == rn) return result;
						}
						
						sx = __cint(sx + stepX);
						rectOff = __cint(rectOff + (stepX << 2));
					}
					sy = __cint(sy + stepY);
				}
				minScaleX *= scaleIncrement;
				minScaleY *= scaleIncrement;
			}
			
			}
			else // TREE BASED DETECTION
			{
				var tr:HaarTree;
				
				while((minScaleX <= maxSizeX && minScaleY <= maxSizeY)
										&& (minScaleX >= cascadeWidth && minScaleY >= cascadeHeight))  
				{
					curWinSizeX = minScaleX;
					curWinSizeY = minScaleY;
					curScaleX = minScaleX / cascadeWidth;
					curScaleY = minScaleY / cascadeHeight;
					curWinArea1 = 1.0 / (minScaleX * minScaleY * 255);
					curWinArea2 = 1.0 / (minScaleX * minScaleY * 65025);
					stepX = (curWinSizeX * increment + 0.5);
					stepY = (curWinSizeY * increment + 0.5);
					edgeThreshold = curWinSizeX * curWinSizeY * edgesDensity;
					
					// rescale rectangles
					
					rc = featureRects;
					while(null != rc)
					{
						c1 = rc.x * curScaleX + 0.5;
						r1 = rc.y * curScaleY + 0.5;
						c2 = rc.w * curScaleX + 0.5;
						r2 = rc.h * curScaleY + 0.5;
						rc.n1 = __cint((r1 * width + c1) << 2);
						rc.n2 = __cint(rc.n1 + (c2 << 2));
						rc.n3 = __cint(((r1 + r2) * width + c1) << 2);
						rc.n4 = __cint(rc.n3 + (c2 << 2));
						rc = rc.nextChainRect;
					}
					
					sy = bounds.y;
					ey = __cint(sy + sh - curWinSizeY);
					while(sy < ey)
					{
						sx = bounds.x;
						ex = __cint(sx + sw - curWinSizeX);
						s1 = __cint(sy * width);
						s2 = __cint((sy + curWinSizeY) * width);
						rectOff = __cint(intOff + ((sy * width + sx)<<2));
						while(sx < ex)
						{
							// Check edges if needed
						
							if (locUseEdges)
							{
								if( __cint(Memory.readInt( edgeOff+((s1 + sx)<<2) )
	                        				- Memory.readInt( edgeOff+((s1 + sx+curWinSizeX)<<2) )
	                        				- Memory.readInt( edgeOff+((s2 + sx)<<2) ) 
	                        				+ Memory.readInt( edgeOff+((s2 + sx+curWinSizeX)<<2))) < edgeThreshold ) 
	                        				{
	                        					// skip it
	                        					sx = __cint(sx + stepX);
												rectOff = __cint(rectOff + (stepX << 2));
												continue;
	                        				}
							}
							
							// Run Cascade
							
							mean = __cint(Memory.readInt( intOff+(i=(s1 + sx)<<2) )
	                        				- Memory.readInt( intOff+(j=(s1 + sx+curWinSizeX)<<2) )
	                        				- Memory.readInt( intOff+(ind=(s2 + sx)<<2) ) 
	                        				+ Memory.readInt( intOff+(ind0=(s2 + sx+curWinSizeX)<<2) )) * curWinArea1;
	                        
	                        vnorm = __cint(Memory.readInt( sqOff + i )
	                        				- Memory.readInt( sqOff + j )
	                        				- Memory.readInt( sqOff + ind ) 
	                        				+ Memory.readInt( sqOff + ind0 )) * curWinArea2;
	                        				
							/*vnorm = (mean * mean) - vnorm;
							if(vnorm < 0) vnorm = -vnorm;
							vnorm = FastMath.sqrt2(vnorm, 0);*/
							vnorm = vnorm - (mean * mean);
							//vnorm = vnorm > 0 ? FastMath.sqrt2(vnorm, 0) : 1.0;
							if (vnorm > 0)
							{
								__asm(__as3(math), __as3(vnorm), CallProperty(__as3(Math.sqrt), 1), SetLocal(vnorm));
							}
							else
							{
								vnorm = 1.0;
							}
	                        
	                        pass = true;
	                        
							st = stages;
							
							while( null != st)
							{
								sum = 0;
								tr = st.trees;
								
								while( null != tr )
								{
									ft = tr.features;
									
									while( null != ft )
									{									
										rect_sum = 0;	
										rc = ft.hfr;
										
										while( null != rc )
										{
											rect_sum +=
													 __cint(Memory.readInt( (rc.n1 + rectOff) )
													- Memory.readInt( (rc.n2 + rectOff) )
													- Memory.readInt( (rc.n3 + rectOff) )
													+ Memory.readInt( (rc.n4 + rectOff) )
													) * rc.weight;

											rc = rc.nextRect;
										}
										
										if(rect_sum*curWinArea1 < ft.threshold * vnorm) 
										{
											sum += ft.leftVal;
											ft = ft.leftNode;
										}
										else
										{
											sum += ft.rightVal;
											ft = ft.rightNode;
										}
									}

									tr = tr.nextTree;
								}
								
								if(sum < st.threshold) 
								{
									pass = false;
									break;
								}

								st = st.nextStage;
							}
							
							if(pass)
							{
								result[rn] = new Rectangle(sx, sy, curWinSizeX, curWinSizeY);
								__asm(IncLocalInt(rn));
								if (maxCandidatesToBreak > -1 && maxCandidatesToBreak == rn) return result;
							}
							
							sx = __cint(sx + stepX);
							rectOff = __cint(rectOff + (stepX << 2));
						}
						sy = __cint(sy + stepY);
					}
					minScaleX *= scaleIncrement;
					minScaleY *= scaleIncrement;
				}
			}
			
			return result;
		}
        
        public function groupRectangles(rectList:Vector.<Rectangle>, groupThreshold:int = 3):Vector.<Rectangle>
		{
			var n:int = rectList.length;
			if(n < 2) return rectList;
			
        	var labels:Vector.<int> = new Vector.<int>(n, true);
        	var nclasses:int = partition(rectList, labels);
        	var rrects:Vector.<Rectangle> = new Vector.<Rectangle>(nclasses, true);
        	var rweights:Vector.<int> = new Vector.<int>(nclasses, true);
        	var i:int, j:int;
        	var filtRect:Vector.<Rectangle> = new Vector.<Rectangle>();
        	
        	for( i = 0; i < nclasses; ++i)
        	{
        		rrects[i] = new Rectangle();
        	}
        	for( i = 0; i < n; ++i)
        	{
				var cls:int = labels[i];
				var rect:Rectangle = rrects[cls];
				var rect2:Rectangle = rectList[i];
		        rect.x += rect2.x;
		        rect.y += rect2.y;
		        rect.width += rect2.width;
		        rect.height += rect2.height;
		        rweights[cls]++;
        	}
        	
        	for( i = 0; i < nclasses; ++i )
		    {
		    	j = rweights[i];
		        if( j <= groupThreshold )
		        {
		            continue;
		        }
		        var s:Number = 1.0 / j;
		        rect = rrects[i];
		        
		        rect.x = int(rect.x * s);
		        rect.y = int(rect.y * s);
		        rect.width = int(rect.width * s);
		        rect.height = int(rect.height * s);
		        
		        filtRect.push(rect);
		        
		        /*filtRect.push(new Rectangle(int(rect.x*s),
		                                int(rect.y*s),
		                                int(rect.width*s),
		                                int(rect.height*s)));*/
		    }
		    return filtRect;
        }
        
        protected function partition(rects:Vector.<Rectangle>, labels:Vector.<int>):int
		{
			var N:int = rects.length;
			var i:int, j:int;
        	var nodes:Vector.<int> = new Vector.<int>(N<<1, true);
        	
        	// The first O(N) pass: create N single-vertex trees
        	for(i = 0, j = 0; i < N; ++i)
        	{
				nodes[j] = -1; __asm(IncLocalInt(j));
				nodes[j] = 0; __asm(IncLocalInt(j));
        	}
        	
        	// The main O(N^2) pass: merge connected components
		    for( i = 0; i < N; ++i )
		    {
		        var root:int = i << 1;
		        
		        // find root
		        while( int(nodes[root]) >= 0 )
		        {
		            root = int(nodes[root]) << 1;
		        }
		        
		        for( j = 0; j < N; ++j )
		        {
		            if( i == j || !HaarInline.similarRects(Rectangle(rects[i]), Rectangle(rects[j])))
		            {
		                continue;
		            }
		            
		            var root2:int = j << 1;
		
		            while( int(nodes[root2]) >= 0 )
		            {
		                root2 = int(nodes[root2]) << 1;
		            }
		            
		            if( root2 != root )
		            {
		                // unite both trees
		                var rank:int = nodes[(__cint(root+1))];
		                var rank2:int = nodes[(__cint(root2+1))];
		                if( rank > rank2 )
		                {
		                    nodes[root2] = root >> 1;
		                }
		                else
		                {
		                    nodes[root] = root2 >> 1;
		                    nodes[__cint(root2+1)] += int(rank == rank2);
		                    root = root2;
		                }
		
		                var k:int = j << 1;
		                var parent:int;
		
		                // compress the path from node2 to root
		                while( (parent = nodes[k]) >= 0 )
		                {
		                    nodes[k] = root >> 1;
		                    k = parent << 1;
		                }
		
		                // compress the path from node to root
		                k = i << 1;
		                while( (parent = nodes[k]) >= 0 )
		                {
		                    nodes[k] = root >> 1;
		                    k = parent << 1;
		                }
		            }		            
		        }
		    }
		    //
		    // Final O(N) pass: enumerate classes
		    var nclasses:int = 0;
		    for( i = 0; i < N; ++i )
		    {
		        root = i << 1;
		        while( nodes[root] >= 0 )
		        {
		            root = nodes[root] << 1;
		        }
		        // re-use the rank as the class label
		        if( nodes[(__cint(root+1))] >= 0 )
		        {
		            nodes[(__cint(root+1))] = ~nclasses++;
		        }
		        labels[i] = ~nodes[(__cint(root+1))];
		    }

			return nclasses;
        }
        
        public function calcRequiredChunkSize(width:int, height:int):int
		{
			var size:int = (((width * height) * 3) << 2);
			return IntMath.nextPow2(size);
		}

		public function set image(bmp:BitmapData):void
		{
			this.bmp = bmp;
			
			imageWidth = bmp.width;
			imageHeight = bmp.height;
			
			rect = bmp.rect;
			
			integralOffset = memPtr;
			sqOffset = integralOffset + ((imageWidth * imageHeight) << 2);
			edgeOffset = sqOffset + ((imageWidth * imageHeight) << 2);
		}
		
		public function get integralImageOffset():int
		{
			return integralOffset;
		}
		public function get integralSquareImageOffset():int
		{
			return sqOffset;
		}
		public function get integralEdgeImageOffset():int
		{
			return edgeOffset;
		}
		public function get cascadeStagesCount():int
		{
			return stagesCount;
		}
		public function get cascadeFeaturesCount():int
		{
			return featuresCount;
		}
		public function get cascadeFeatureRectsCount():int
		{
			return featureRectsCount;
		}
		public function get cascadeTreesCount():int
		{
			return treesCount;
		}
		
		protected function getHaarClassifier(haarData:XML):XML 
		{
			return haarData.*.(@type_id == "opencv-haar-classifier")[0];
		}

		public function setupCascadeData(haarData:XML, treeBased:Boolean = false):void
		{
			var cascadeData:XML = getHaarClassifier(haarData);
			if(treeBased)
			{
				parseTreeBasedCascades(cascadeData);
			} 
			else 
			{
			
				treeBasedCascades = false;
				
				var sizes:XML = cascadeData.size.text()[0];
	            
	            var sizesArr:Array = sizes.toString().match( /\d+/g );
	            
				cascadeWidth = sizesArr[0];
				cascadeHeight = sizesArr[1];
				
				var stagesList:XMLList = cascadeData.stages[0].children();
				
				stagesCount = stagesList.length();
				featureRectsCount = 0;
				featuresCount = 0;
	            
	            stages = null;
				featureRects = null;
	            
	            var st:HaarStage;
	            var ft:HaarFeature;
	            var rc:HaarFeatureRect;
	            var rc2:HaarFeatureRect;
	            
	            for each (var s:XML in stagesList)
	            {				
	            	if(null == st)
	            	{
						st = stages = new HaarStage();
					}
					else
					{
						st = st.nextStage = new HaarStage();
					}
					
					st.threshold = parseFloat(s.stage_threshold.text()[0].toString());
					
					var treesList:XMLList = s.trees.children();
					
					for each (var t:XML in treesList)
					{
						var nodeNodes:XMLList = t.elements();
						for each (var featNode:XML in nodeNodes)
						{
							if(null == st.features)
							{
								ft = st.features = new HaarFeature();
							}
							else
							{
								ft = ft.nextFeature = new HaarFeature();
							}
							
							ft.threshold = parseFloat(featNode.threshold.text()[0].toString());
							ft.leftVal = parseFloat(featNode.left_val.text()[0].toString());
							ft.rightVal = parseFloat(featNode.right_val.text()[0].toString());
							
							//ft.tilted = parseInt(featNode.feature.tilted.text()[0].toString()) == 1;
							
							var rectsnodes:XMLList = featNode.feature.rects.children();
							
							ft.rn = rectsnodes.length();
							for each (var r:XML in rectsnodes)
							{				
								if(null == ft.hfr)
								{
									rc = ft.hfr = new HaarFeatureRect();
								}
								else
								{
									rc = rc.nextRect = new HaarFeatureRect();
								}
								
								if(null == featureRects)
								{
									rc2 = featureRects = rc;
								}
								else
								{
									rc2 = rc2.nextChainRect = rc;
								}
											
								var rarray:Array = r.text()[0].toString().split(" ");
								
								rc.x = parseInt(rarray[0]);
								rc.y = parseInt(rarray[1]);
								rc.w = parseInt(rarray[2]);
								rc.h = parseInt(rarray[3]);
								rc.weight = parseFloat(rarray[4]);
								
								featureRectsCount++;
							}
							featuresCount++;
						}
					}
	            }
			}
		}
		
		protected function parseTreeBasedCascades(cascadeData:XML):void
		{
			treeBasedCascades = true;
			
			var sizes:XML = cascadeData.size.text()[0];
            
            var sizesArr:Array = sizes.toString().match( /\d+/g );
            
			cascadeWidth = sizesArr[0];
			cascadeHeight = sizesArr[1];
			
			var stagesList:XMLList = cascadeData.stages[0].children();
			
			stagesCount = stagesList.length();
			featureRectsCount = 0;
			featuresCount = 0;
			treesCount = 0;
			
			stages = null;
			featureRects = null;
            
            var st:HaarStage;
            var ft:HaarFeature;
            var ft2:HaarFeature;
            var tr:HaarTree;
            var rc:HaarFeatureRect;
            var rc2:HaarFeatureRect;
            
            for each (var s:XML in stagesList)
            {
            	if(null == st)
            	{
					st = stages = new HaarStage();
				}
				else
				{
					st = st.nextStage = new HaarStage();
				}
				
				st.threshold = parseFloat(s.stage_threshold.text()[0].toString());
				
				var treesList:XMLList = s.trees.children();
				
				for each (var t:XML in treesList)
				{
					if(null == st.trees)
					{
						tr = st.trees = new HaarTree();
					}
					else
					{
						tr = tr.nextTree = new HaarTree();
					}
					
					var nodeNodes:XMLList = t.elements();
					
					var featuresMap:Vector.<HaarFeature> = tr.featuresMap = new Vector.<HaarFeature>();
					
					var mapLIdx:Vector.<int> = new Vector.<int>();
					var mapRIdx:Vector.<int> = new Vector.<int>();
					
					for each (var featNode:XML in nodeNodes)
					{
						if(null == tr.features)
						{
							ft = tr.features = new HaarFeature();
						}
						else
						{
							ft = new HaarFeature();
						}
						
						featuresMap.push(ft);
						
						ft.threshold = parseFloat(featNode.threshold.text()[0].toString());
						
						if (featNode.descendants("left_val").length() > 0)
                        {
							ft.leftVal = parseFloat(featNode.left_val.text()[0].toString());
							mapLIdx.push(-1);
                        }
                        else
                        {
                        	ft.leftVal = 0.0;
							mapLIdx.push( parseInt(featNode.left_node.text()[0].toString()) );
						}
						
						if (featNode.descendants("right_val").length() > 0)
                        {
							ft.rightVal = parseFloat(featNode.right_val.text()[0].toString());
							mapRIdx.push(-1);
                        }
                        else
                        {
                        	ft.rightVal = 0.0;
							mapRIdx.push( parseInt(featNode.right_node.text()[0].toString()) );
						}
						
						
						//ft.tilted = parseInt(featNode.feature.tilted.text()[0].toString()) == 1;
						
						var rectsnodes:XMLList = featNode.feature.rects.children();
						
						ft.rn = rectsnodes.length();
						
						for each (var r:XML in rectsnodes)
						{
							if(null == ft.hfr)
							{
								rc = ft.hfr = new HaarFeatureRect();
							}
							else
							{
								rc = rc.nextRect = new HaarFeatureRect();
							}
							
							if(null == featureRects)
							{
								rc2 = featureRects = rc;
							}
							else
							{
								rc2 = rc2.nextChainRect = rc;
							}
							
							var rarray:Array = r.text()[0].toString().split(" ");
							
							rc.x = parseInt(rarray[0]);
							rc.y = parseInt(rarray[1]);
							rc.w = parseInt(rarray[2]);
							rc.h = parseInt(rarray[3]);
							rc.weight = parseFloat(rarray[4]);

							featureRectsCount++;
						}
						featuresCount++;
					}
					
					// map feature nodes
					for(var i:int = 0; i < featuresMap.length; ++i)
					{
						ft2 = featuresMap[i];
						if(mapLIdx[i] > -1) 
						{
							ft2.leftNode = featuresMap[ mapLIdx[i] ];
						} else {
							ft2.leftNode = null;
						}
						if(mapRIdx[i] > -1) 
						{
							ft2.rightNode = featuresMap[ mapRIdx[i] ];
						} else {
							ft2.rightNode = null;
						}
					}
					treesCount++;
				}
            }
		}
	}
}