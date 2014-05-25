package ru.inspirit.image.encoder
{
	internal final class BitString {
		public var len:int = 0;
		public var val:int = 0;
		public function BitString(vl:int, ln:int) {
			val = vl;
			len = ln;
		}
	}
}
