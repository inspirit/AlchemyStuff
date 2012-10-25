package ru.inspirit.image.edges
{
	import apparat.asm.CallProperty;
	import apparat.asm.DecLocalInt;
	import apparat.asm.GetLocal;
	import apparat.asm.IfEqual;
	import apparat.asm.IncLocalInt;
	import apparat.asm.Jump;
	import apparat.asm.PushByte;
	import apparat.asm.SetLocal;
	import apparat.asm.__as3;
	import apparat.asm.__asm;
	import apparat.asm.__beginRepeat;
	import apparat.asm.__cint;
	import apparat.asm.__endRepeat;
	import apparat.memory.Memory;
	/**
	 * @author Eugene Zatepyakin
	 */
	public final class FreiChenEdgeDetector
	{
		public function detect(imgPtr:int, edgPtr:int, w:int, h:int):void
		{
			var i:int;
			var eh:int = __cint(h-1);
			var row:int = __cint(imgPtr + 1 + w);
			var out:int = __cint(edgPtr + 4 + (w<<2));
			
			var f1:Number = 0.35355339059327373;
			var sqrt2:Number = 1.4142135623730951;
			
			var math:*;
			__asm(__as3(Math), SetLocal(math));
			
			var rem:int = __cint(((w-2) >> 4) + 1);
			var tail:int = __cint(((w-2) % 16) + 1);
			var br:int;
			
			var a:int, b:int, c:int, d:int, e:int;
			
			for(i = 1; i < eh; ++i)
			{
				var top:int = __cint(row - w);
				var bot:int = __cint(row + w);
				a = Memory.readUnsignedByte(__cint(bot - 1));
				b = Memory.readUnsignedByte(__cint(top - 1));
				c = Memory.readUnsignedByte(__cint(top + 1));
				d = Memory.readUnsignedByte(bot);
				e = Memory.readUnsignedByte(top);
				
				br = rem;
				__asm(
					'loop:',
					DecLocalInt(br),
					GetLocal(br),
					PushByte(0),
					IfEqual('endLoop')
					);
					__beginRepeat(16);
					//
					var p11:int = Memory.readUnsignedByte(row);
					var p01:int = Memory.readUnsignedByte( __cint(row-1));
					//var p00:int = b;
					//var p10:int = e;
					//var p20:int = c;
					var p21:int = Memory.readUnsignedByte(__cint(row+1));
					var p22:int = Memory.readUnsignedByte(__cint(bot+1));
					//var p12:int = d;
					//var p02:int = a;
					//
					var g1:Number = f1  * ( b + sqrt2 * e + c - a - sqrt2 * d - p22 );
			        var g2:Number = f1  * ( b + sqrt2 * p01 + a - c - sqrt2 * p21 - p22 );
			        var g3:Number = f1  * ( p01 + sqrt2 * c + d - e - sqrt2 * a - p21 );
			        var g4:Number = f1  * ( p11 + sqrt2 * b + d - e - sqrt2 * p22 - p01 );
			        var g5:Number = 0.5 * __cint( e + d - p01 - p21 );
			        var g6:Number = 0.5 * __cint( c + a - b - p22 );
			        var g7:Number = 0.166666667 * __cint( b + c + (p11<<2) + a + p22 - (e<<1) - (d<<1) - (p01<<1) - (p21<<1) );
			        var g8:Number = 0.166666667 * __cint( e + d + (p11<<2) + p01 + p21 - (b<<1) - (c<<1) - (a<<1) - (p22<<1) );
			        var g9:Number = 0.333333333 * __cint( b + e + c + p01 + p11 + p21 + a + d + p22 );
			        
			        var M:Number = g1 * g1 + g2 * g2 + g3 * g3 + g4 * g4;
			        var S:Number = g5 * g5 + g6 * g6 + g7 * g7 + g8 * g8 + g9 * g9 + M;
			        var vv:Number =  M / S;
			        __asm(__as3(math), __as3(vv), CallProperty(__as3(Math.sqrt), 1), SetLocal(vv));
			        Memory.writeInt(vv * 0xFF, out);
			        //
					//
					__asm(IncLocalInt(row), IncLocalInt(top), IncLocalInt(bot));
        			out = __cint(out + 4);
					//
					a=d;
					b=e;
					e=c;
					d = Memory.readUnsignedByte(bot);
					c = Memory.readUnsignedByte(__cint(top + 1));
			        //
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
					//
					p11 = Memory.readUnsignedByte(row);
					p01 = Memory.readUnsignedByte( __cint(row-1));
					//p00 = b;
					//p10 = e;
					//p20 = c;
					p21 = Memory.readUnsignedByte(__cint(row+1));
					p22 = Memory.readUnsignedByte(__cint(bot+1));
					//p12 = d;
					//p02 = a;
					//
					g1 = f1  * ( b + sqrt2 * e + c - a - sqrt2 * d - p22 );
			        g2 = f1  * ( b + sqrt2 * p01 + a - c - sqrt2 * p21 - p22 );
			        g3 = f1  * ( p01 + sqrt2 * c + d - e - sqrt2 * a - p21 );
			        g4 = f1  * ( p11 + sqrt2 * b + d - e - sqrt2 * p22 - p01 );
			        g5 = 0.5 * __cint( e + d - p01 - p21 );
			        g6 = 0.5 * __cint( c + a - b - p22 );
			        g7 = 0.166666667 * __cint( b + c + (p11<<2) + a + p22 - (e<<1) - (d<<1) - (p01<<1) - (p21<<1) );
			        g8 = 0.166666667 * __cint( e + d + (p11<<2) + p01 + p21 - (b<<1) - (c<<1) - (a<<1) - (p22<<1) );
			        g9 = 0.333333333 * __cint( b + e + c + p01 + p11 + p21 + a + d + p22 );
			        
			        M = g1 * g1 + g2 * g2 + g3 * g3 + g4 * g4;
			        S = g5 * g5 + g6 * g6 + g7 * g7 + g8 * g8 + g9 * g9 + M;
			        vv =  M / S;
			         __asm(__as3(math), __as3(vv), CallProperty(__as3(Math.sqrt), 1), SetLocal(vv));
			        Memory.writeInt(vv * 0xFF, out);
			        //
					//
					__asm(IncLocalInt(row), IncLocalInt(top), IncLocalInt(bot));
        			out = __cint(out + 4);
					//
					a=d;
					b=e;
					e=c;
					d = Memory.readUnsignedByte(bot);
					c = Memory.readUnsignedByte(__cint(top + 1));
			        //
				__asm(
					Jump('loop1'),
					'endLoop1:'
					);
				row = __cint(row + 2);
				out = __cint(out + 8);
			}
		}
	}
}