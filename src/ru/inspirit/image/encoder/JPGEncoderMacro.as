package ru.inspirit.image.encoder
{
	import apparat.asm.IncLocalInt;
	import apparat.asm.__asm;
	import apparat.asm.__cint;
	import apparat.inline.Macro;
	import apparat.memory.Memory;

	/**
	 * @author Eugene Zatepyakin
	 */
	internal final class JPGEncoderMacro extends Macro
	{
		/*
		public static function writeBits(bs:BitString, bytenew:int, bytepos:int, _baddr:int):void
		{
			var numbit:int = bs.len;
			var bn:int = (bytenew << numbit) | bs.val;
			numbit = __cint(numbit + 7 - bytepos);
			while(numbit>=8) {
			 numbit = __cint(numbit - 8);
			 var b:int = (bn>>>numbit) & 0xFF;
			 Memory.writeByte(b, _baddr); __asm(IncLocalInt(_baddr));
			 Memory.writeByte(0, _baddr); _baddr=__cint(_baddr+int(b==0xFF));
			}
			bytenew = bn & __cint((1<<numbit)-1);
			bytepos = __cint(7 - numbit);
		}
		*/
		public static function writeBitsPtr(bs_ptr:int, bytenew:int, bytepos:int, _baddr:int):void
		{
			var numbit:int =  Memory.readInt(__cint(bs_ptr+4));
			var bn:int = (bytenew << numbit) | Memory.readInt(bs_ptr);
			numbit = __cint(numbit + 7 - bytepos);
			while(numbit>=8) {
			 numbit = __cint(numbit - 8);
			 var b:int = (bn>>>numbit) & 0xFF;
			 Memory.writeByte(b, _baddr); __asm(IncLocalInt(_baddr));
			 Memory.writeByte(0, _baddr); _baddr=__cint(_baddr+int(b==0xFF));
			}
			bytenew = bn & __cint((1<<numbit)-1);
			bytepos = __cint(7 - numbit);
		}
	}
}
