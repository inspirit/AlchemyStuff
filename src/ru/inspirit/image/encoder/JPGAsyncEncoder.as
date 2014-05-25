package ru.inspirit.image.encoder
{
	import apparat.asm.__cint;
	import apparat.math.IntMath;

	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	/**
	 * @author Eugene Zatepyakin
	 */
	public final class JPGAsyncEncoder extends EventDispatcher
	{
		private static const ZigZagList:IntLL = IntLL.create([
			 0, 1, 5, 6,14,15,27,28,
			 2, 4, 7,13,16,26,29,42,
			 3, 8,12,17,25,30,41,43,
			 9,11,18,24,31,40,44,53,
			10,19,23,32,39,45,52,54,
			20,22,33,38,46,51,55,60,
			21,34,37,47,50,56,59,61,
			35,36,48,49,57,58,62,63
		]);

		private static const YQTList:IntLL = IntLL.create([
			16, 11, 10, 16, 24, 40, 51, 61,
			12, 12, 14, 19, 26, 58, 60, 55,
			14, 13, 16, 24, 40, 57, 69, 56,
			14, 17, 22, 29, 51, 87, 80, 62,
			18, 22, 37, 56, 68,109,103, 77,
			24, 35, 55, 64, 81,104,113, 92,
			49, 64, 78, 87,103,121,120,101,
			72, 92, 95, 98,112,100,103, 99
		]);
		private static const UVQTList:IntLL = IntLL.create([
			17, 18, 24, 47, 99, 99, 99, 99,
			18, 21, 26, 66, 99, 99, 99, 99,
			24, 26, 56, 99, 99, 99, 99, 99,
			47, 66, 99, 99, 99, 99, 99, 99,
			99, 99, 99, 99, 99, 99, 99, 99,
			99, 99, 99, 99, 99, 99, 99, 99,
			99, 99, 99, 99, 99, 99, 99, 99,
			99, 99, 99, 99, 99, 99, 99, 99
		]);

		private const YTable:Vector.<int> = new Vector.<int>(64, true);
		private const UVTable:Vector.<int> = new Vector.<int>(64, true);
		private const fdtbl_YList:IntLL = IntLL.create(new Array(64));
		private const fdtbl_UVList:IntLL = IntLL.create(new Array(64));

		private var DCY:int=0;
		private var DCU:int=0;
		private var DCV:int=0;

		// Async properties
		private var _async:Boolean = false;
		private var asyncTimer:Timer;
		private var SrcWidth:int = 0;
		private var SrcHeight:int = 0;
		private var Source:BitmapData;
		private var TotalSize:int = 0;
		private var _blocksPerIteration:int = 128;
		private var PercentageInc:int = 0;
		private var NextProgressAt:int = 0;
		private var CurrentTotalPos:int = 0;
		private var Working:Boolean = false;

		private var MultiSource:Array;
		private var MultiIndX:int = 0;
		private var MultiIndY:int = 0;
		private var buffer:BitmapData;
		private var xpos:int = 0;
		private var ypos:int = 0;
		
		/**
		 * Constructor for JPGAsyncEncoder class
		 *
		 * @param quality The quality level between 1 and 100 that detrmines the level of compression used in the generated JPEG
		 */
		public function JPGAsyncEncoder(quality:Number = 50)
		{
			if (quality <= 0) {
				quality = 1;
			}
			if (quality > 100) {
				quality = 100;
			}
			var sf:int = 0;
			if (quality < 50) {
				sf = (5000 / quality);
			} else {
				sf = (200 - (quality << 1));
			}
			// Create tables
			initHuffmanTbl();
			initCategoryNumber();
			initQuantTables(sf);
			
			// Init Async timer
			asyncTimer = new Timer(10);
		}

		private function initQuantTables(sf:int):void {
			var i:int;
			var t:int;
			var ZigZag:IntLL = ZigZagList;
			var YQT:IntLL = YQTList;
			var _Table:Vector.<int> = YTable;
			for (i = 0; i < 64; ++i) {
				t = (__cint(YQTList.data*sf+50)/100);
				YQT = YQT.next;
				t = IntMath.max(1, t);
				t = IntMath.min(255, t);
				/*if (t < 1) {
					t = 1;
				} else if (t > 255) {
					t = 255;
				}*/
				_Table[ZigZag.data] = t;
				ZigZag = ZigZag.next;
			}
			ZigZag = ZigZagList;
			var UVQT:IntLL = UVQTList;
			_Table = UVTable;
			for (i = 0; i < 64; ++i) {
				t = (__cint(UVQT.data*sf+50)/100);
				UVQT = UVQT.next;
				t = IntMath.max(1, t);
				t = IntMath.min(255, t);
				/*if (t < 1) {
					t = 1;
				} else if (t > 255) {
					t = 255;
				}*/
				_Table[ZigZag.data] = t;
				ZigZag = ZigZag.next;
			}
			ZigZag = ZigZagList;
			var fdtbl_Y:IntLL = fdtbl_YList;
			var fdtbl_UV:IntLL = fdtbl_UVList;
			_Table = YTable;
			var _Table2:Vector.<int> = UVTable;
			for (i = 0; i < 64; ++i) {
				fdtbl_Y.data  =  _Table[ZigZag.data] << 3;
				fdtbl_UV.data = _Table2[ZigZag.data] << 3;
				ZigZag = ZigZag.next;
				fdtbl_Y = fdtbl_Y.next;
				fdtbl_UV = fdtbl_UV.next;
			}
		}

		private static const std_dc_luminance_nrcodesList:IntLL = IntLL.create([0,0,1,5,1,1,1,1,1,1,0,0,0,0,0,0,0]);
		private static const std_dc_luminance_valuesList:IntLL = IntLL.create([0,1,2,3,4,5,6,7,8,9,10,11]);
		private static const std_ac_luminance_nrcodesList:IntLL = IntLL.create([0,0,2,1,3,3,2,4,3,5,5,4,4,0,0,1,0x7d]);
		private static const std_ac_luminance_valuesList:IntLL = IntLL.create([
			0x01,0x02,0x03,0x00,0x04,0x11,0x05,0x12,
			0x21,0x31,0x41,0x06,0x13,0x51,0x61,0x07,
			0x22,0x71,0x14,0x32,0x81,0x91,0xa1,0x08,
			0x23,0x42,0xb1,0xc1,0x15,0x52,0xd1,0xf0,
			0x24,0x33,0x62,0x72,0x82,0x09,0x0a,0x16,
			0x17,0x18,0x19,0x1a,0x25,0x26,0x27,0x28,
			0x29,0x2a,0x34,0x35,0x36,0x37,0x38,0x39,
			0x3a,0x43,0x44,0x45,0x46,0x47,0x48,0x49,
			0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,
			0x5a,0x63,0x64,0x65,0x66,0x67,0x68,0x69,
			0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,
			0x7a,0x83,0x84,0x85,0x86,0x87,0x88,0x89,
			0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,
			0x99,0x9a,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,
			0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,
			0xb7,0xb8,0xb9,0xba,0xc2,0xc3,0xc4,0xc5,
			0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,
			0xd5,0xd6,0xd7,0xd8,0xd9,0xda,0xe1,0xe2,
			0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,
			0xf1,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
			0xf9,0xfa
		]);

		private static const std_dc_chrominance_nrcodesList:IntLL = IntLL.create([0,0,3,1,1,1,1,1,1,1,1,1,0,0,0,0,0]);
		private static const std_dc_chrominance_valuesList:IntLL = IntLL.create([0,1,2,3,4,5,6,7,8,9,10,11]);
		private static const std_ac_chrominance_nrcodesList:IntLL = IntLL.create([0,0,2,1,2,4,4,3,4,7,5,4,4,0,1,2,0x77]);
		private static const std_ac_chrominance_valuesList:IntLL = IntLL.create([
			0x00,0x01,0x02,0x03,0x11,0x04,0x05,0x21,
			0x31,0x06,0x12,0x41,0x51,0x07,0x61,0x71,
			0x13,0x22,0x32,0x81,0x08,0x14,0x42,0x91,
			0xa1,0xb1,0xc1,0x09,0x23,0x33,0x52,0xf0,
			0x15,0x62,0x72,0xd1,0x0a,0x16,0x24,0x34,
			0xe1,0x25,0xf1,0x17,0x18,0x19,0x1a,0x26,
			0x27,0x28,0x29,0x2a,0x35,0x36,0x37,0x38,
			0x39,0x3a,0x43,0x44,0x45,0x46,0x47,0x48,
			0x49,0x4a,0x53,0x54,0x55,0x56,0x57,0x58,
			0x59,0x5a,0x63,0x64,0x65,0x66,0x67,0x68,
			0x69,0x6a,0x73,0x74,0x75,0x76,0x77,0x78,
			0x79,0x7a,0x82,0x83,0x84,0x85,0x86,0x87,
			0x88,0x89,0x8a,0x92,0x93,0x94,0x95,0x96,
			0x97,0x98,0x99,0x9a,0xa2,0xa3,0xa4,0xa5,
			0xa6,0xa7,0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,
			0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xc2,0xc3,
			0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0xd2,
			0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,
			0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,
			0xea,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
			0xf9,0xfa
		]);

		private function computeHuffmanTbl(nrcodesList:IntLL, std_tableList:IntLL):Vector.<BitString>
		{
			var codevalue:int = 0;
			var nrcodes:IntLL = nrcodesList.next;
			var std_table:IntLL = std_tableList;
			var HT:Vector.<BitString> = new Vector.<BitString>(251, true);
			for (var k:int = 1; k <= 16; ++k) {
				var nr:int = nrcodes.data;
				for (var j:int=1; j<=nr; ++j) {
					HT[std_table.data] = new BitString(codevalue, k);
					std_table = std_table.next;
					++codevalue;
				}
				nrcodes = nrcodes.next;
				codevalue<<=1;
			}
			return HT;
		}

		private var YDC_HT:Vector.<BitString>;
		private var UVDC_HT:Vector.<BitString>;
		private var YAC_HT:Vector.<BitString>;
		private var UVAC_HT:Vector.<BitString>;

		private function initHuffmanTbl():void {
			YDC_HT = computeHuffmanTbl(std_dc_luminance_nrcodesList,std_dc_luminance_valuesList);
			UVDC_HT = computeHuffmanTbl(std_dc_chrominance_nrcodesList,std_dc_chrominance_valuesList);
			YAC_HT = computeHuffmanTbl(std_ac_luminance_nrcodesList,std_ac_luminance_valuesList);
			UVAC_HT = computeHuffmanTbl(std_ac_chrominance_nrcodesList,std_ac_chrominance_valuesList);
		}

		private const bitcode:Vector.<BitString> = new Vector.<BitString>(65535, true);
		private const category:Vector.<int> = new Vector.<int>(65535, true);

		private function initCategoryNumber():void {
			var nrlower:int = 1;
			var nrupper:int = 2;
			var nr:int;
			var n:int;
			for (var cat:int=1; cat<=15; ++cat) {
				//Positive numbers
				for (nr=nrlower; nr<nrupper; ++nr) {
					n = __cint(32767+nr);
					category[n] = cat;
					bitcode[n] = new BitString(nr, cat);
				}
				//Negative numbers
				for (nr=-(nrupper-1); nr<=-nrlower; ++nr) {
					n = __cint(32767+nr);
					category[n] = cat;
					bitcode[n] = new BitString(__cint(nrupper-1+nr), cat);
				}
				nrlower <<= 1;
				nrupper <<= 1;
			}
		}

		// IO functions

		private var byteout:ByteArray;
		private var bytenew:int = 0;
		private var bytepos:int = 7;

		private function writeBits(bs:BitString):void {
			var value:int = bs.val;
			var posval:int = __cint(bs.len-1);
			while ( posval >= 0 ) {
				if (value & (1 << posval) ) {
					bytenew |= (1 << bytepos);
				}
				posval = __cint(posval-1);
				bytepos = __cint(bytepos-1);
				if (bytepos < 0) {
					if (bytenew == 0xFF) {
						writeByte(0xFF);
						writeByte(0);
					}
					else {
						writeByte(bytenew);
					}
					bytepos=7;
					bytenew=0;
				}
			}
		}

		private function writeByte(value:int):void {
			byteout.writeByte(value);
		}

		private function writeWord(value:int):void {
			writeByte((value>>8));
			writeByte((value   ));
		}

		// DCT & quantization core
		private function fDCTQuant(data:IntLL8x8, fdtbl:IntLL):IntLL8x8 {
			var tmp0:int, tmp1:int, tmp2:int, tmp3:int, tmp4:int, tmp5:int, tmp6:int, tmp7:int;
			var tmp10:int, tmp11:int, tmp12:int, tmp13:int;
			var d0:int, d1:int, d2:int, d3:int, d4:int, d5:int, d6:int, d7:int;
			var z1:int, z2:int, z3:int, z4:int, z5:int;
			var i:int;
			var row:IntLL8x8, col:IntLL8x8;
			var dataOff:IntLL8x8;
			/* Pass 1: process rows. */
			/* Note results are scaled up by sqrt(8) compared to a true DCT; */
			/* furthermore, we scale the results by 2**2. */
			row = data;
			for (i=0; i<8; ++i) {
				dataOff = row;
				d0 = dataOff.data;
				dataOff = dataOff.next;
				d1 = dataOff.data;
				dataOff = dataOff.next;
				d2 = dataOff.data;
				dataOff = dataOff.next;
				d3 = dataOff.data;
				dataOff = dataOff.next;
				d4 = dataOff.data;
				dataOff = dataOff.next;
				d5 = dataOff.data;
				dataOff = dataOff.next;
				d6 = dataOff.data;
				dataOff = dataOff.next;
				d7 = dataOff.data;

				tmp0 = __cint(d0+d7);
				tmp7 = __cint(d0-d7);
				tmp1 = __cint(d1+d6);
				tmp6 = __cint(d1-d6);
				tmp2 = __cint(d2+d5);
				tmp5 = __cint(d2-d5);
				tmp3 = __cint(d3+d4);
				tmp4 = __cint(d3-d4);

				/* Even part per LL&M figure 1 --- note that published figure is faulty;
				 * rotator "sqrt(2)*c1" should be "sqrt(2)*c6".
				 */
				tmp10 = __cint(tmp0 + tmp3);
				tmp13 = __cint(tmp0 - tmp3);
				tmp11 = __cint(tmp1 + tmp2);
				tmp12 = __cint(tmp1 - tmp2);

				z1 = __cint((tmp12 + tmp13) * 4433);

				dataOff = row;
				dataOff.data = __cint((tmp10 + tmp11) << 2);
				dataOff = dataOff.next.next;
				dataOff.data = __cint((z1 + tmp13 * 6270 + (0x400)) >> 11);
				dataOff = dataOff.next.next;
				dataOff.data = __cint((tmp10 - tmp11) << 2);
				dataOff = dataOff.next.next;
				dataOff.data = __cint((z1 - tmp12 * 15137 + (0x400)) >> 11);

				/* Odd part per figure 8 --- note paper omits factor of sqrt(2).
				 * cK represents cos(K*pi/16).
				 * i0..i3 in the paper are tmp4..tmp7 here.
				 */
				z1 = __cint(tmp4 + tmp7);
				z2 = __cint(tmp5 + tmp6);
				z3 = __cint(tmp4 + tmp6);
				z4 = __cint(tmp5 + tmp7);
				z5 = __cint((z3 + z4) * 9633);

				tmp4 = __cint(tmp4 * 2446);
				tmp5 = __cint(tmp5 * 16819);
				tmp6 = __cint(tmp6 * 25172);
				tmp7 = __cint(tmp7 * 12299);
				z1 = __cint(- z1 * 7373);
				z2 = __cint(- z2 * 20995);
				z3 = __cint(- z3 * 16069);
				z4 = __cint(- z4 * 3196);

				z3 = __cint(z3 +z5);
				z4 = __cint(z4 +z5);

				dataOff = row.next;
				dataOff.data = __cint((tmp7 + z1 + z4 + (0x400)) >> 11);
				dataOff = dataOff.next.next;
				dataOff.data = __cint((tmp6 + z2 + z3 + (0x400)) >> 11);
				dataOff = dataOff.next.next;
				dataOff.data = __cint((tmp5 + z2 + z4 + (0x400)) >> 11);
				dataOff = dataOff.next.next;
				dataOff.data = __cint((tmp4 + z1 + z3 + (0x400)) >> 11);

				row = row.down; /* advance pointer to next row */
			}

			/* Pass 2: process columns.
			 * We remove the PASS1_BITS scaling, but leave the results scaled up
			 * by an overall factor of 8.
			 */
			col = data;
			for (i=0; i<8; ++i) {
				dataOff = col;
				d0 = dataOff.data;
				dataOff = dataOff.down;
				d1 = dataOff.data;
				dataOff = dataOff.down;
				d2 = dataOff.data;
				dataOff = dataOff.down;
				d3 = dataOff.data;
				dataOff = dataOff.down;
				d4 = dataOff.data;
				dataOff = dataOff.down;
				d5 = dataOff.data;
				dataOff = dataOff.down;
				d6 = dataOff.data;
				dataOff = dataOff.down;
				d7 = dataOff.data;

				tmp0 = __cint(d0+d7);
				tmp7 = __cint(d0-d7);
				tmp1 = __cint(d1+d6);
				tmp6 = __cint(d1-d6);
				tmp2 = __cint(d2+d5);
				tmp5 = __cint(d2-d5);
				tmp3 = __cint(d3+d4);
				tmp4 = __cint(d3-d4);

				/* Even part per LL&M figure 1 --- note that published figure is faulty;
				 * rotator "sqrt(2)*c1" should be "sqrt(2)*c6".
				 */
				tmp10 = __cint(tmp0 + tmp3);
				tmp13 = __cint(tmp0 - tmp3);
				tmp11 = __cint(tmp1 + tmp2);
				tmp12 = __cint(tmp1 - tmp2);

				z1 = __cint(((tmp12 + tmp13) * 4433));

				dataOff = col;
				dataOff.data = __cint((tmp10 + tmp11 + (0x2)) >> 2);
				dataOff = dataOff.down.down;
				dataOff.data = __cint((z1 + tmp13 * 6270 + (0x4000)) >> 15);
				dataOff = dataOff.down.down;
				dataOff.data = __cint((tmp10 - tmp11 + (0x2)) >> 2);
				dataOff = dataOff.down.down;
				dataOff.data = __cint((z1 - tmp12 * 15137 + (0x4000)) >> 15);

				/* Odd part per figure 8 --- note paper omits factor of sqrt(2).
				 * cK represents cos(K*pi/16).
				 * i0..i3 in the paper are tmp4..tmp7 here.
				 */
				z1 = __cint(tmp4 + tmp7);
				z2 = __cint(tmp5 + tmp6);
				z3 = __cint(tmp4 + tmp6);
				z4 = __cint(tmp5 + tmp7);
				z5 = __cint((z3 + z4) * 9633);

				tmp4 = __cint(tmp4 * 2446);
				tmp5 = __cint(tmp5 * 16819);
				tmp6 = __cint(tmp6 * 25172);
				tmp7 = __cint(tmp7 * 12299);
				z1 = __cint(- z1 * 7373);
				z2 = __cint(- z2 * 20995);
				z3 = __cint(- z3 * 16069);
				z4 = __cint(- z4 * 3196);

				z3 = __cint(z3 +z5);
				z4 = __cint(z4 +z5);

				dataOff = col.down;
				dataOff.data = __cint((tmp7 + z1 + z4 + (0x4000)) >> 15);
				dataOff = dataOff.down.down;
				dataOff.data = __cint((tmp6 + z2 + z3 + (0x4000)) >> 15);
				dataOff = dataOff.down.down;
				dataOff.data = __cint((tmp5 + z2 + z4 + (0x4000)) >> 15);
				dataOff = dataOff.down.down;
				dataOff.data = __cint((tmp4 + z1 + z3 + (0x4000)) >> 15);

				col = col.next; /* advance pointer to next column */
			}

			// Quantize/descale the coefficients
			dataOff = data;
			for (i=0; i<64; ++i) {
				// Apply the quantization and scaling factor & Round to nearest integer
				var qval:int = fdtbl.data;
				fdtbl = fdtbl.next;
				var temp:int = dataOff.data;
				if (temp < 0) {
					temp = -temp;
					temp = __cint(temp + (qval >> 1));	/* for rounding */
					if (temp >= qval) temp /= qval;
					else temp = 0;
					temp = -temp;
				} else {
					temp = __cint(temp + (qval >> 1));	/* for rounding */
					if (temp >= qval) temp /= qval;
					else temp = 0;
				}
				dataOff.data = temp;
				dataOff = dataOff.next;
			}
			return data;
		}

		// Chunk writing

		private function writeAPP0():void {
			writeWord(0xFFE0); // marker
			writeWord(16); // length
			writeByte(0x4A); // J
			writeByte(0x46); // F
			writeByte(0x49); // I
			writeByte(0x46); // F
			writeByte(0); // = "JFIF",'\0'
			writeByte(1); // versionhi
			writeByte(1); // versionlo
			writeByte(0); // xyunits
			writeWord(1); // xdensity
			writeWord(1); // ydensity
			writeByte(0); // thumbnwidth
			writeByte(0); // thumbnheight
		}

		private function writeSOF0(width:int, height:int):void {
			writeWord(0xFFC0); // marker
			writeWord(17);   // length, truecolor YUV JPG
			writeByte(8);    // precision
			writeWord(height);
			writeWord(width);
			writeByte(3);    // nrofcomponents
			writeByte(1);    // IdY
			writeByte(0x11); // HVY
			writeByte(0);    // QTY
			writeByte(2);    // IdU
			writeByte(0x11); // HVU
			writeByte(1);    // QTU
			writeByte(3);    // IdV
			writeByte(0x11); // HVV
			writeByte(1);    // QTV
		}

		private function writeDQT():void {
			writeWord(0xFFDB); // marker
			writeWord(132);	   // length
			writeByte(0);
			var i:int;
			var _tb1:Vector.<int> = YTable;
			for (i=0; i<64; ++i) {
				writeByte(_tb1[i]);
			}
			writeByte(1);
			_tb1 = UVTable;
			for (i=0; i<64; ++i) {
				writeByte(_tb1[i]);
			}
		}

		private function writeDHT():void {
			writeWord(0xFFC4); // marker
			writeWord(0x01A2); // length
			var i:int;

			writeByte(0); // HTYDCinfo
			var std_dc_luminance_nrcodes:IntLL = std_dc_luminance_nrcodesList.next;
			for (i=1; i<=16; ++i) {
				writeByte(std_dc_luminance_nrcodes.data);
				std_dc_luminance_nrcodes = std_dc_luminance_nrcodes.next;
			}
			var std_dc_luminance_values:IntLL = std_dc_luminance_valuesList;
			for (i=0; i<=11; ++i) {
				writeByte(std_dc_luminance_values.data);
				std_dc_luminance_values = std_dc_luminance_values.next;
			}

			writeByte(0x10); // HTYACinfo
			var std_ac_luminance_nrcodes:IntLL = std_ac_luminance_nrcodesList.next;
			for (i=1; i<=16; ++i) {
				writeByte(std_ac_luminance_nrcodes.data);
				std_ac_luminance_nrcodes = std_ac_luminance_nrcodes.next;
			}
			var std_ac_luminance_values:IntLL = std_ac_luminance_valuesList;
			for (i=0; i<=161; ++i) {
				writeByte(std_ac_luminance_values.data);
				std_ac_luminance_values = std_ac_luminance_values.next;
			}

			writeByte(1); // HTUDCinfo
			var std_dc_chrominance_nrcodes:IntLL = std_dc_chrominance_nrcodesList.next;
			for (i=1; i<=16; ++i) {
				writeByte(std_dc_chrominance_nrcodes.data);
				std_dc_chrominance_nrcodes = std_dc_chrominance_nrcodes.next;
			}
			var std_dc_chrominance_values:IntLL = std_dc_chrominance_valuesList;
			for (i=0; i<=11; ++i) {
				writeByte(std_dc_chrominance_values.data);
				std_dc_chrominance_values = std_dc_chrominance_values.next;
			}

			writeByte(0x11); // HTUACinfo
			var std_ac_chrominance_nrcodes:IntLL = std_ac_chrominance_nrcodesList.next;
			for (i=1; i<=16; ++i) {
				writeByte(std_ac_chrominance_nrcodes.data);
				std_ac_chrominance_nrcodes = std_ac_chrominance_nrcodes.next;
			}
			var std_ac_chrominance_values:IntLL = std_ac_chrominance_valuesList;
			for (i=0; i<=161; ++i) {
				writeByte(std_ac_chrominance_values.data);
				std_ac_chrominance_values = std_ac_chrominance_values.next;
			}
		}

		private function writeSOS():void {
			writeWord(0xFFDA); // marker
			writeWord(12); // length
			writeByte(3); // nrofcomponents
			writeByte(1); // IdY
			writeByte(0); // HTY
			writeByte(2); // IdU
			writeByte(0x11); // HTU
			writeByte(3); // IdV
			writeByte(0x11); // HTV
			writeByte(0); // Ss
			writeByte(0x3f); // Se
			writeByte(0); // Bf
		}

		// Core processing
		private const DU:Vector.<int> = new Vector.<int>(64, true);

		private function processDU(CDU:IntLL8x8, fdtbl:IntLL, DC:int, HTDC:Vector.<BitString>, HTAC:Vector.<BitString>):int {
			var EOB:BitString = HTAC[0x00];
			var M16zeroes:BitString = HTAC[0xF0];
			var i:int;

			var DU_DCT:IntLL8x8 = fDCTQuant(CDU, fdtbl);
			//ZigZag reorder
			var ZigZag:IntLL = ZigZagList;
			var _du:Vector.<int> = DU;
			for (i=0;i<64;++i) {
				_du[ZigZag.data] = DU_DCT.data;
				ZigZag = ZigZag.next;
				DU_DCT = DU_DCT.next;
			}
			var Diff:int = __cint(_du[0] - DC);
			DC = _du[0];
			//Encode DC
			if (Diff==0) {
				writeBits(HTDC[0]); // Diff might be 0
			} else {
				i = __cint(32767+Diff);
				writeBits(HTDC[category[i]]);
				writeBits(bitcode[i]);
			}
			//Encode ACs
			var end0pos:int = 63;
			while((end0pos>0)&&(_du[end0pos]==0)) --end0pos;
			//end0pos = first element in reverse order !=0
			if ( end0pos == 0) {
				writeBits(EOB);
				return DC;
			}
			i = 1;
			var _cat:Vector.<int> = category;
			var _bit:Vector.<BitString> = bitcode;
			while ( i <= end0pos ) {
				var startpos:int = i;
				while((_du[i]==0) && (i<=end0pos)) ++i;
				var nrzeroes:int = __cint(i-startpos);
				var n:int;
				if ( nrzeroes >= 16 ) {
					n = nrzeroes >> 4;
					for (var nrmarker:int=1; nrmarker <= n; ++nrmarker) {
						writeBits(M16zeroes);
					}
					nrzeroes = (nrzeroes&0xF);
				}
				n = __cint(32767+_du[i]);
				writeBits(HTAC[__cint(((nrzeroes<<4)+_cat[n]))]);
				writeBits(_bit[n]);
				++i;
			}
			if ( end0pos != 63 ) {
				writeBits(EOB);
			}
			return DC;
		}

		private const YDUBlock:IntLL8x8 = IntLL8x8.create(new Array(64));
		private const UDUBlock:IntLL8x8 = IntLL8x8.create(new Array(64));
		private const VDUBlock:IntLL8x8 = IntLL8x8.create(new Array(64));
		private static const fltrRGB2YUV:ColorMatrixFilter = new ColorMatrixFilter([
			 0.29900,  0.58700,  0.11400, 0,   0,
			-0.16874, -0.33126,  0.50000, 0, 128,
			 0.50000, -0.41869, -0.08131, 0, 128,
			       0,        0,        0, 1,   0
		]);
		private static const orgn:Point = new Point();

		//private static const rgb_ycc_tab:Array = new Array(2048);
		//private function init_rgb_ycc_tab():void {
		//	for (var i:int = 0; i <= 255; i++) {
		//		rgb_ycc_tab[i]      =  19595 * i;
		//		rgb_ycc_tab[(i+ 256)>>0] =  38470 * i;
		//		rgb_ycc_tab[(i+ 512)>>0] =   7471 * i + 0x8000;
		//		rgb_ycc_tab[(i+ 768)>>0] = -11059 * i;
		//		rgb_ycc_tab[(i+1024)>>0] = -21709 * i;
				/* We use a rounding fudge-factor of 0.5-epsilon for Cb and Cr.
				 * This ensures that the maximum output will round to MAXJSAMPLE
				 * not MAXJSAMPLE+1, and thus that we don't have to range-limit.
				 */
		//		rgb_ycc_tab[(i+1280)>>0] =  32768 * i + 0x807FFF;
				/*  B=>Cb and R=>Cr tables are the same
				    rgb_ycc_tab[i+R_CR_OFF] = FIX(0.50000) * i    + CBCR_OFFSET + ONE_HALF-1;
				*/
		//		rgb_ycc_tab[(i+1536)>>0] = -27439 * i;
		//		rgb_ycc_tab[(i+1792)>>0] = - 5329 * i;
		//	}
		//}

		private function RGB2YUV(img:BitmapData, xpos:int, ypos:int):void {
			var YDU:IntLL8x8 = YDUBlock;
			var UDU:IntLL8x8 = UDUBlock;
			var VDU:IntLL8x8 = VDUBlock;
			for (var y:int=0; y<8; ++y) {
				for (var x:int=0; x<8; ++x) {
					var P:int = img.getPixel(xpos+x,ypos+y);
					var R:int = ((P>>16)&0xFF);
					var G:int = ((P>> 8)&0xFF);
					var B:int = ((P    )&0xFF);
					/* RGB2YUV with ColorMatrixFilter */
					YDU.data = __cint(R-128);
					UDU.data = __cint(G-128);
					VDU.data = __cint(B-128);
					YDU = YDU.next;
					UDU = UDU.next;
					VDU = VDU.next;
				}
			}
		}

		public function encodeAsync(image:BitmapData):void
		{
			internalEncode(image, image.width, image.height);
		}

		public function encodeMultiToOne(imgs:Array):void
		{
			internalMultiEncode(imgs);
		}

		public function cleanUp(disposeBitmapData:Boolean = false):void
		{
			asyncTimer.stop();
			if(buffer) buffer.dispose();
			if (MultiSource.length && disposeBitmapData)
			{
				clearSources();
			}
		}

		private function internalMultiEncode(imgs:Array):void
		{
			if (Working) {
				asyncTimer.stop();
				if (asyncTimer.hasEventListener(TimerEvent.TIMER)) {
					asyncTimer.removeEventListener(TimerEvent.TIMER, EncodeTick);
					asyncTimer.removeEventListener(TimerEvent.TIMER, MultiEncodeTick);
				}
			}

			_async = true;
			Working = true;
			MultiSource = imgs;
			MultiIndX = 0;
			MultiIndY = 0;
			xpos = ypos = 0;
			Source = BitmapData(MultiSource[MultiIndY][MultiIndX]);
			buffer = new BitmapData(_blocksPerIteration << 3, 8, true, 0x00000000);
			buffer.lock();

			SrcWidth = 0;
			SrcHeight = 0;

			var i:uint;
			var iMultiSource0Len:int = MultiSource[0].length;
			for (i = 0; i < iMultiSource0Len; ++i) {
				SrcWidth += (MultiSource[0][i] as BitmapData).width;
			}
			var iMultiSourceLen:int = MultiSource.length;
			for (i = 0; i < iMultiSourceLen; ++i) {
				SrcHeight += (MultiSource[i][0] as BitmapData).height;
			}

			TotalSize = SrcWidth*SrcHeight;
			PercentageInc = TotalSize/100;
			NextProgressAt = PercentageInc;
			CurrentTotalPos = 0;

			StartEncode();

			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, 0, TotalSize));
			asyncTimer.addEventListener(TimerEvent.TIMER, MultiEncodeTick);
			asyncTimer.start();
		}

		private var imgRGB2YUV:BitmapData;

	    private function internalEncode(newSource:BitmapData, width:int, height:int):void
	    {
			if (Working) {
				asyncTimer.stop();
				if (asyncTimer.hasEventListener(TimerEvent.TIMER)) {
					asyncTimer.removeEventListener(TimerEvent.TIMER, EncodeTick);
					asyncTimer.removeEventListener(TimerEvent.TIMER, MultiEncodeTick);
				}
			}

			_async = true;
			Working = true;
			Source = newSource;
			SrcWidth = width;
			SrcHeight = height;
			TotalSize = width*height;
			PercentageInc = TotalSize/100;
			NextProgressAt = PercentageInc;
			CurrentTotalPos = 0;
			xpos = ypos = 0;

			StartEncode();

			imgRGB2YUV = Source.clone();
			imgRGB2YUV.lock();
			imgRGB2YUV.applyFilter(imgRGB2YUV, imgRGB2YUV.rect, orgn, fltrRGB2YUV);

			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, 0, TotalSize));
			asyncTimer.addEventListener(TimerEvent.TIMER, EncodeTick);
			asyncTimer.start();
	    }

	    private function StartEncode():void
	    {
		    // Initialize bit writer
			byteout = new ByteArray();
			bytenew = 0;
			bytepos = 7;

			// Add JPEG headers
			writeWord(0xFFD8); // SOI
			writeAPP0();
			writeDQT();
			writeSOF0(SrcWidth, SrcHeight);
			writeDHT();
			writeSOS();

			DCY = 0;
			DCV = 0;
			DCU = 0;
	    }

		private function MultiEncodeTick(e:TimerEvent):void
		{
			fillBuffer();

			for(var i:int = 0; i < _blocksPerIteration; ++i)
			{
				RGB2YUV(buffer, i << 3, 0);
				DCY = processDU(YDUBlock, fdtbl_YList,  DCY,  YDC_HT,  YAC_HT);
				DCU = processDU(UDUBlock, fdtbl_UVList, DCU, UVDC_HT, UVAC_HT);
				DCV = processDU(VDUBlock, fdtbl_UVList, DCV, UVDC_HT, UVAC_HT);

				xpos += 8;
				if ( xpos >= Source.width ) {
					if ( MultiIndX < MultiSource[MultiIndY].length - 1 ) {
						xpos = xpos - Source.width;
						MultiIndX++;
						Source = BitmapData(MultiSource[MultiIndY][MultiIndX]);
					} else {
						xpos = 0;
						ypos += 8;
						MultiIndX = 0;
						Source = BitmapData(MultiSource[MultiIndY][MultiIndX]);
						if ( ypos >= Source.height ) {
							if ( MultiIndY < MultiSource.length - 1 ) {
								ypos = ypos - Source.height;
								MultiIndY++;
							} else {
								asyncTimer.stop();
								finishEncode();
								return;
							}
						}
						Source = BitmapData(MultiSource[MultiIndY][MultiIndX]);
						break;
					}
				}

				CurrentTotalPos += 64;

				if( CurrentTotalPos >= NextProgressAt ) {
					dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, CurrentTotalPos, TotalSize));
					NextProgressAt += PercentageInc;
				}
			}
		}

		private function fillBuffer():void
		{
			//buffer.lock();
			buffer.fillRect(buffer.rect, 0x00000000);

			var bmp:BitmapData = Source;
			var ox:int = xpos;
			var oy:int = ypos;
			var pw:int = buffer.width;
			var w:int = Math.min(pw, bmp.width - ox);
			var h:int = Math.min(8, bmp.height - oy);

			buffer.copyPixels(bmp, new Rectangle(ox, oy, w, h), orgn, bmp, new Point(ox, oy), true);

			var i:int = 0;
			var tx:int = w;
			var nw:int;
			if ( w < pw ) {
				while (tx < pw) {
					if ( MultiIndX + i < MultiSource[MultiIndY].length - 1 ) {
						i++;
						bmp = BitmapData(MultiSource[MultiIndY][MultiIndX + i]);
						nw = Math.min(pw - tx, bmp.width);
						buffer.copyPixels(bmp, new Rectangle(0, oy, nw, h), new Point(tx, 0), bmp, new Point(0, oy), true);
						tx += nw;
					} else {
						break;
					}
				}
				/*
				if ( MultiIndX < MultiSource[MultiIndY].length - 1 ) {
					bmp = BitmapData(MultiSource[MultiIndY][MultiIndX + 1]);
					buffer.copyPixels(bmp, new Rectangle(0, oy, pw - w, h), new Point(w, 0), bmp, new Point(0, oy), true);
				}*/
			}

			if ( h < 8 ) {
				if ( MultiIndY < MultiSource.length - 1 ) {
					bmp = BitmapData(MultiSource[MultiIndY + 1][MultiIndX]);
					buffer.copyPixels(bmp, new Rectangle(ox, 0, w, 8 - h), new Point(0, h), bmp, new Point(ox, 0), true);

					i = 0;
					tx = w;
					while (tx < pw) {
						if ( MultiIndX + i < MultiSource[MultiIndY + 1].length - 1 ) {
							i++;
							bmp = BitmapData(MultiSource[MultiIndY + 1][MultiIndX + i]);
							nw = Math.min(pw - tx, bmp.width);
							buffer.copyPixels(bmp, new Rectangle(0, 0, nw, 8 - h), new Point(tx, h), bmp, orgn, true);
							tx += nw;
						} else {
							break;
						}
					}

				}
			}

			/*
			if ( w < pw && h < 8 ) {
				if ( MultiIndX < MultiSource[MultiIndY].length - 1 && MultiIndY < MultiSource.length - 1 ) {
					bmp = BitmapData(MultiSource[MultiIndY + 1][MultiIndX + 1]);
					buffer.copyPixels(bmp, new Rectangle(0, 0, pw - w, 8 - h), new Point(w, h), bmp, origin, true);
				}
			}*/
			//buffer.unlock();
			buffer.applyFilter(buffer, buffer.rect, orgn, fltrRGB2YUV);
		}

	    private function EncodeTick(e:TimerEvent):void
	    {
			for (var i:int = 0; i < _blocksPerIteration; ++i)
			{
				RGB2YUV(imgRGB2YUV, xpos, ypos);
				DCY = processDU(YDUBlock, fdtbl_YList,  DCY,  YDC_HT,  YAC_HT);
				DCU = processDU(UDUBlock, fdtbl_UVList, DCU, UVDC_HT, UVAC_HT);
				DCV = processDU(VDUBlock, fdtbl_UVList, DCV, UVDC_HT, UVAC_HT);

				xpos += 8;

				if(xpos >= SrcWidth)
				{
					xpos = 0;
					ypos += 8;
				}

				if(ypos >= SrcHeight)
				{
					asyncTimer.stop();
					finishEncode();
					return;
				}

				CurrentTotalPos += 64;

				if(CurrentTotalPos >= NextProgressAt)
				{
					dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, CurrentTotalPos, TotalSize));
					NextProgressAt += PercentageInc;
				}
			}
	    }

	    private function finishEncode():void
	    {
			// Do the bit alignment of the EOI marker
			if ( bytepos >= 0 ) {
				writeBits(new BitString((1<<(bytepos+1))-1, bytepos+1));
			}

			writeWord(0xFFD9); //EOI

			if(_async){
				if(imgRGB2YUV) imgRGB2YUV.dispose();
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, TotalSize, TotalSize));
				dispatchEvent(new Event(Event.COMPLETE));
			}

			Working = false;
	    }

		private function clearSources():void
		{
			var bmp:BitmapData;
			var iMultiSourceLen:int = MultiSource.length;
			for (var i:int = 0; i < iMultiSourceLen; ++i) {
				var iMultiSource0Len:int = MultiSource[0].length;
				for (var j:int = 0; j < iMultiSource0Len; ++j) {
					bmp = BitmapData(MultiSource[i][j]);
					bmp.dispose();
				}
			}
			MultiSource = [];
		}

		public function get blocksPerIteration():int
	    {
			return _blocksPerIteration;
		}
		
		/**
		 * @param Number of 8x8 blocks to proceed every 10ms.
		 */
	    public function set blocksPerIteration(val:int):void
	    {
			_blocksPerIteration = Math.min(val, 256);
		}

	    public function get encodedImageData():ByteArray
	    {
			return byteout;
		}
	}
}
