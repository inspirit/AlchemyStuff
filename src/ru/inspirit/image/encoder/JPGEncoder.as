package ru.inspirit.image.encoder
{
	import apparat.math.FastMath;
	import apparat.asm.DecLocalInt;
	import apparat.asm.IncLocalInt;
	import apparat.asm.Jump;
	import apparat.asm.__asm;
	import apparat.asm.__beginRepeat;
	import apparat.asm.__cint;
	import apparat.asm.__endRepeat;
	import apparat.math.IntMath;
	import apparat.memory.Memory;

	import flash.display.BitmapData;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.system.ApplicationDomain;
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	public final class JPGEncoder
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
		
		private var _quality:Number = 50;
		
		private const HEAD_DIM_POS:int = 159;
		
		private var YDC_HT_ptr:int = 0;
		private var UVDC_HT_ptr:int = YDC_HT_ptr + (251 << 3);
		private var YAC_HT_ptr:int = UVDC_HT_ptr + (251 << 3);
		private var UVAC_HT_ptr:int = YAC_HT_ptr + (251 << 3);
		private var bitcode_ptr:int = UVAC_HT_ptr + (251 << 3);
		private var category_ptr:int = bitcode_ptr + (65535 << 3);
		private var DU_ptr:int = category_ptr + (65535 << 2);
		
		private const DATA_BA:ByteArray = new ByteArray();
		
		/**
		 * Constructor for JPGEncoder class
		 *
		 * @param quality The quality level between 1 and 100 that detrmines the level of compression used in the generated JPEG
		 */
		public function JPGEncoder(quality:Number = 50)
		{
			this.quality = quality;
		}
		
		public function set quality(value:Number):void
		{
			_quality = FastMath.max(value, 1);
			_quality = FastMath.min(_quality, 100);
			var sf:int = 0;
			if (_quality < 50) {
				sf = (5000 / _quality);
			} else {
				sf = (200 - (_quality << 1));
			}
			//
			DATA_BA.clear();
			DATA_BA.endian = Endian.LITTLE_ENDIAN;
			DATA_BA.length = DU_ptr + (64 << 2);
			// Create tables
			initHuffmanTbl();
			initCategoryNumber();
			initQuantTables(sf);
			buildHeaders();
		}
		
		public function get quality():Number
		{
			return _quality;
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
				t = 1 ^ ((1 ^ t) & -int(1 < t));//IntMath.max(1, t);
				t = t ^ ((255 ^ t) & -int(255 < t));//IntMath.min(255, t);
				_Table[ZigZag.data] = t;
				ZigZag = ZigZag.next;
			}
			ZigZag = ZigZagList;
			var UVQT:IntLL = UVQTList;
			_Table = UVTable;
			for (i = 0; i < 64; ++i) {
				t = (__cint(UVQT.data*sf+50)/100);
				UVQT = UVQT.next;
				t = 1 ^ ((1 ^ t) & -int(1 < t));//IntMath.max(1, t);
				t = t ^ ((255 ^ t) & -int(255 < t));//IntMath.min(255, t);
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

		private function computeHuffmanTbl(memPtr:int, nrcodesList:IntLL, std_tableList:IntLL):void
		{
			var codevalue:int = 0;
			var nrcodes:IntLL = nrcodesList.next;
			var std_table:IntLL = std_tableList;
			//var HT:Vector.<BitString> = new Vector.<BitString>(251, true);
			for (var k:int = 1; k <= 16; ++k) {
				var nr:int = nrcodes.data;
				for (var j:int=1; j<=nr; ++j) {
					//HT[std_table.data] = new BitString( codevalue, k );
					DATA_BA.position = memPtr + (std_table.data << 3);
					DATA_BA.writeInt(codevalue);
					DATA_BA.writeInt(k);
					std_table = std_table.next;
					++codevalue;
				}
				nrcodes = nrcodes.next;
				codevalue<<=1;
			}

			//return HT;
		}
		
		private function initHuffmanTbl():void {
			/*YDC_HT = */computeHuffmanTbl(YDC_HT_ptr, std_dc_luminance_nrcodesList,std_dc_luminance_valuesList);
			/*UVDC_HT = */computeHuffmanTbl(UVDC_HT_ptr, std_dc_chrominance_nrcodesList,std_dc_chrominance_valuesList);
			/*YAC_HT = */computeHuffmanTbl(YAC_HT_ptr, std_ac_luminance_nrcodesList,std_ac_luminance_valuesList);
			/*UVAC_HT = */computeHuffmanTbl(UVAC_HT_ptr, std_ac_chrominance_nrcodesList,std_ac_chrominance_valuesList);
		}

		private function initCategoryNumber():void {
			var nrlower:int = 1;
			var nrupper:int = 2;
			var nr:int;
			var n:int;
			for (var cat:int=1; cat<=15; ++cat) {
				//Positive numbers
				for (nr=nrlower; nr<nrupper; ++nr) {
					n = __cint(32767+nr);
					//category[n] = cat;
					//bitcode[n] = new BitString(nr, cat);
					//
					DATA_BA.position = bitcode_ptr + (n << 3);
					DATA_BA.writeInt(nr);
					DATA_BA.writeInt(cat);
					//
					DATA_BA.position = category_ptr + (n << 2);
					DATA_BA.writeInt(cat);
				}
				//Negative numbers
				for (nr=-(nrupper-1); nr<=-nrlower; ++nr) {
					n = __cint(32767+nr);
					//category[n] = cat;
					//bitcode[n] = new BitString(__cint(nrupper-1+nr), cat);
					//
					DATA_BA.position = bitcode_ptr + (n << 3);
					DATA_BA.writeInt(__cint(nrupper-1+nr));
					DATA_BA.writeInt(cat);
					//
					DATA_BA.position = category_ptr + (n << 2);
					DATA_BA.writeInt(cat);
				}
				nrlower <<= 1;
				nrupper <<= 1;
			}
		}

		// IO functions
		// Chunk writing
		
		private function buildHeaders():void
		{
			// writeAPP0
			HEAD_BA.clear();
			writeWord(0xFFD8, HEAD_BA); // header start
			
			writeWord(0xFFE0, HEAD_BA); // marker
			writeWord(16, HEAD_BA); // length
			writeByte(0x4A, HEAD_BA); // J
			writeByte(0x46, HEAD_BA); // F
			writeByte(0x49, HEAD_BA); // I
			writeByte(0x46, HEAD_BA); // F
			writeByte(0, HEAD_BA); // = "JFIF",'\0'
			writeByte(1, HEAD_BA); // versionhi
			writeByte(1, HEAD_BA); // versionlo
			writeByte(0, HEAD_BA); // xyunits
			writeWord(1, HEAD_BA); // xdensity
			writeWord(1, HEAD_BA); // ydensity
			writeByte(0, HEAD_BA); // thumbnwidth
			writeByte(0, HEAD_BA); // thumbnheight
			//writeDQT
			writeWord(0xFFDB, HEAD_BA); // marker
			writeWord(132, HEAD_BA);	   // length
			writeByte(0, HEAD_BA);
			var i:int;
			var _tb1:Vector.<int> = YTable;
			for (i=0; i<64; ++i) {
				writeByte(_tb1[i], HEAD_BA);
			}
			writeByte(1, HEAD_BA);
			_tb1 = UVTable;
			for (i=0; i<64; ++i) {
				writeByte(_tb1[i], HEAD_BA);
			}
			//SOFO
			writeWord(0xFFC0, HEAD_BA); // marker
			writeWord(17, HEAD_BA);   // length, truecolor YUV JPG
			writeByte(8, HEAD_BA);    // precision
			
			writeWord(0, HEAD_BA); // height
			writeWord(0, HEAD_BA); // width
			writeByte(3, HEAD_BA);    // nrofcomponents
			writeByte(1, HEAD_BA);    // IdY
			writeByte(0x11, HEAD_BA); // HVY
			writeByte(0, HEAD_BA);    // QTY
			writeByte(2, HEAD_BA);    // IdU
			writeByte(0x11, HEAD_BA); // HVU
			writeByte(1, HEAD_BA);    // QTU
			writeByte(3, HEAD_BA);    // IdV
			writeByte(0x11, HEAD_BA); // HVV
			writeByte(1, HEAD_BA);    // QTV
			//
			//DHT
			writeWord(0xFFC4, HEAD_BA); // marker
			writeWord(0x01A2, HEAD_BA); // length

			writeByte(0, HEAD_BA); // HTYDCinfo
			var std_dc_luminance_nrcodes:IntLL = std_dc_luminance_nrcodesList.next;
			for (i=1; i<=16; ++i) {
				writeByte(std_dc_luminance_nrcodes.data, HEAD_BA);
				std_dc_luminance_nrcodes = std_dc_luminance_nrcodes.next;
			}
			var std_dc_luminance_values:IntLL = std_dc_luminance_valuesList;
			for (i=0; i<=11; ++i) {
				writeByte(std_dc_luminance_values.data, HEAD_BA);
				std_dc_luminance_values = std_dc_luminance_values.next;
			}

			writeByte(0x10, HEAD_BA); // HTYACinfo
			var std_ac_luminance_nrcodes:IntLL = std_ac_luminance_nrcodesList.next;
			for (i=1; i<=16; ++i) {
				writeByte(std_ac_luminance_nrcodes.data, HEAD_BA);
				std_ac_luminance_nrcodes = std_ac_luminance_nrcodes.next;
			}
			var std_ac_luminance_values:IntLL = std_ac_luminance_valuesList;
			for (i=0; i<=161; ++i) {
				writeByte(std_ac_luminance_values.data, HEAD_BA);
				std_ac_luminance_values = std_ac_luminance_values.next;
			}

			writeByte(1, HEAD_BA); // HTUDCinfo
			var std_dc_chrominance_nrcodes:IntLL = std_dc_chrominance_nrcodesList.next;
			for (i=1; i<=16; ++i) {
				writeByte(std_dc_chrominance_nrcodes.data, HEAD_BA);
				std_dc_chrominance_nrcodes = std_dc_chrominance_nrcodes.next;
			}
			var std_dc_chrominance_values:IntLL = std_dc_chrominance_valuesList;
			for (i=0; i<=11; ++i) {
				writeByte(std_dc_chrominance_values.data, HEAD_BA);
				std_dc_chrominance_values = std_dc_chrominance_values.next;
			}

			writeByte(0x11, HEAD_BA); // HTUACinfo
			var std_ac_chrominance_nrcodes:IntLL = std_ac_chrominance_nrcodesList.next;
			for (i=1; i<=16; ++i) {
				writeByte(std_ac_chrominance_nrcodes.data, HEAD_BA);
				std_ac_chrominance_nrcodes = std_ac_chrominance_nrcodes.next;
			}
			var std_ac_chrominance_values:IntLL = std_ac_chrominance_valuesList;
			for (i=0; i<=161; ++i) {
				writeByte(std_ac_chrominance_values.data, HEAD_BA);
				std_ac_chrominance_values = std_ac_chrominance_values.next;
			}
			//SOS
			writeWord(0xFFDA, HEAD_BA); // marker
			writeWord(12, HEAD_BA); // length
			writeByte(3, HEAD_BA); // nrofcomponents
			writeByte(1, HEAD_BA); // IdY
			writeByte(0, HEAD_BA); // HTY
			writeByte(2, HEAD_BA); // IdU
			writeByte(0x11, HEAD_BA); // HTU
			writeByte(3, HEAD_BA); // IdV
			writeByte(0x11, HEAD_BA); // HTV
			writeByte(0, HEAD_BA); // Ss
			writeByte(0x3f, HEAD_BA); // Se
			writeByte(0, HEAD_BA); // Bf
		}
		
		private function writeByte(value:int, byteout:ByteArray):void {
			byteout.writeByte(value);
		}

		private function writeWord(value:int, byteout:ByteArray):void {
			writeByte((value>>8), byteout);
			writeByte((value   ), byteout);
		}
		
		// Core processing
		//private const DU:Vector.<int> = new Vector.<int>(64, true);

		private const YDUBlock:IntLL8x8 = IntLL8x8.create(new Array(64));
		private const UDUBlock:IntLL8x8 = IntLL8x8.create(new Array(64));
		private const VDUBlock:IntLL8x8 = IntLL8x8.create(new Array(64));
		private const fltrRGB2YUV:ColorMatrixFilter = new ColorMatrixFilter([
			 0.29900,  0.58700,  0.11400, 0,   0,
			-0.16874, -0.33126,  0.50000, 0, 128,
			 0.50000, -0.41869, -0.08131, 0, 128,
			       0,        0,        0, 1,   0
		]);
		private const orgn:Point = new Point();
		
		private const applicationDomain:ApplicationDomain = ApplicationDomain.currentDomain;
		
		private const HEAD_BA:ByteArray = new ByteArray();
		
		/**
		 * Created a JPG image from the specified BitmapData
		 *
		 * @param image The BitmapData that will be converted into the JPG format.
		 * @return a ByteArray representing the JPG encoded image data.
		 */
		public function encode(image:BitmapData):ByteArray
		{
			var img_r:Rectangle = image.rect;
			var img:BitmapData = image.clone();
			img.applyFilter(img, img_r, orgn, fltrRGB2YUV);
			var height:int = img.height;
			var width:int = img.width;
			var _baddr:int = DATA_BA.length;
			var _baddr0:int = _baddr;
			
			var ba_buff:ByteArray = new ByteArray();
			ba_buff.endian = Endian.LITTLE_ENDIAN;
			ba_buff.length = __cint( _baddr + width * height * 4 );
			
			ba_buff.position = 0;
			DATA_BA.position = 0;
			ba_buff.writeBytes( DATA_BA );
			
			var oldDomainMemory:ByteArray = applicationDomain.domainMemory;
			applicationDomain.domainMemory = ba_buff;

			// Initialize bit writer
			var byteout:ByteArray = new ByteArray();
			var bytenew:int = 0;
			var bytepos:int = 7;

			// Add JPEG headers
			HEAD_BA.position = HEAD_DIM_POS;
			HEAD_BA.writeByte(height>>8);
			HEAD_BA.writeByte(height   );
			HEAD_BA.writeByte(width>>8);
			HEAD_BA.writeByte(width   );

			// Encode 8x8 macroblocks
			var DCY:int = 0;
			var DCU:int = 0;
			var DCV:int = 0;
			
			var data:Vector.<uint> = img.getVector(img_r);
			var data_p:int = 0;
			var size:int = __cint(width * height - 1);
			
			var CDU:IntLL8x8;
			var fdtbl:IntLL;
			var DC:int;
			//
			var HTDC_ptr:int;
			var HTAC_ptr:int;
			
			var _cat_ptr:int = category_ptr;
			var _bit_ptr:int = bitcode_ptr;
			var _du_ptr:int = DU_ptr;

			//var bs:BitString;
			var i:int;
			var EOB_ptr:int;
			var M16zeroes_ptr:int;
			
			var tmp0:int, tmp1:int, tmp2:int, tmp3:int, tmp4:int, tmp5:int, tmp6:int, tmp7:int;
			var tmp10:int, tmp11:int, tmp12:int, tmp13:int;
			var d0:int, d1:int, d2:int, d3:int, d4:int, d5:int, d6:int, d7:int;
			var z1:int, z2:int, z3:int, z4:int, z5:int;
			var row:IntLL8x8, col:IntLL8x8;
			var dataOff:IntLL8x8;

			for (var ypos:int = 0; ypos < height; ) 
			{
				data_p = __cint( ypos * width );
				for (var xpos:int = 0; xpos < width; ) 
				{
					//RGB2YUV
					var YDU:IntLL8x8 = YDUBlock;
					var UDU:IntLL8x8 = UDUBlock;
					var VDU:IntLL8x8 = VDUBlock;
					var loc_p:int;
					var ty:int = IntMath.min( 8, __cint(height - ypos));
					//if(ty < 8) throw new Error(ty);
					for (var y:int=0; y<ty; ++y) {
						loc_p = __cint(data_p + y*width);
						//loc_p = IntMath.min(loc_p, max_datap_wh);
						//for (var x:int=0; x<8; ++x) {
						__beginRepeat(8);
							var P:uint = data[loc_p];
							/* RGB2YUV with ColorMatrixFilter */
							YDU.data = __cint(((P>>16)&0xFF)-128);
							UDU.data = __cint(((P>> 8)&0xFF)-128);
							VDU.data = __cint(((P    )&0xFF)-128);
							YDU = YDU.next;
							UDU = UDU.next;
							VDU = VDU.next;
							//
							//__asm(IncLocalInt(loc_p));
							loc_p = __cint(loc_p + int(loc_p<size));
						__endRepeat();
						//}
					}
					xpos = __cint(xpos + 8);
					data_p = __cint(data_p + 8);
					//
					//processDU(CDU:IntLL8x8, fdtbl:IntLL, DC:int, HTDC:Vector.<BitString>, HTAC:Vector.<BitString>):int
					//DCY = processDU(YDUBlock, fdtbl_YList,  DCY,  YDC_HT,  YAC_HT);
					CDU = YDUBlock;
					fdtbl = fdtbl_YList;
					DC = DCY;
					
					HTDC_ptr = YDC_HT_ptr;
					HTAC_ptr = YAC_HT_ptr;
					EOB_ptr = __cint(HTAC_ptr + (0x00<<3));
					M16zeroes_ptr = __cint(HTAC_ptr + (0xF0<<3));
		
					//var DU_DCT:IntLL8x8 = fDCTQuant(CDU, fdtbl);
					// fDCTQuant(data:IntLL8x8, fdtbl:IntLL):IntLL8x8 
					
					/* Pass 1: process rows. */
					/* Note results are scaled up by sqrt(8) compared to a true DCT; */
					/* furthermore, we scale the results by 2**2. */
					row = CDU;
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
					col = CDU;
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
					dataOff = CDU;
					for (i=0; i<64;) {
						// Apply the quantization and scaling factor & Round to nearest integer
						var qval:int = fdtbl.data;
						fdtbl = fdtbl.next;
						var temp:int = dataOff.data;
						temp = __cint( temp + ( 1 - ( int( temp < 0 ) << 1 )) * ( qval >> 1 ) );
						dataOff.data = __cint( temp / qval );
						dataOff = dataOff.next;
						__asm(IncLocalInt(i));
					}
					var DU_DCT:IntLL8x8 = CDU;
					
					//-----------------------------------
					
					//ZigZag reorder
					var ZigZag:IntLL = ZigZagList;					
					for (i=0;i<64;) {
						Memory.writeInt( DU_DCT.data, __cint(_du_ptr + (ZigZag.data<<2)));
						ZigZag = ZigZag.next;
						DU_DCT = DU_DCT.next;
						__asm(IncLocalInt(i));
					}
					
					var Diff:int = __cint(Memory.readInt(_du_ptr) - DC);					DC = Memory.readInt(_du_ptr);
					
					//Encode DC
					if (Diff==0) {
						JPGEncoderMacro.writeBitsPtr(HTDC_ptr, bytenew, bytepos, _baddr);
					} else {
						i = __cint(32767+Diff);
						z1 = i << 2;
						z2 = __cint(HTDC_ptr+(Memory.readInt(_cat_ptr+z1)<<3));
						JPGEncoderMacro.writeBitsPtr(z2, bytenew, bytepos, _baddr);

						z1 =  __cint( _bit_ptr + (i<<3));
						JPGEncoderMacro.writeBitsPtr(z1, bytenew, bytepos, _baddr );
					}
					//Encode ACs
					var end0pos:int = 63;
					while((end0pos>0)&&(Memory.readInt(__cint(_du_ptr+(end0pos<<2)))==0)) __asm(DecLocalInt(end0pos));//--end0pos;
					if ( end0pos == 0) {
						JPGEncoderMacro.writeBitsPtr( EOB_ptr, bytenew, bytepos, _baddr );
						
						__asm(Jump('breakPass'));
					}
					i = 1;

					while ( i <= end0pos ) {
						var startpos:int = i;						while((Memory.readInt(__cint(_du_ptr+(i<<2)))==0) && (i<=end0pos)) __asm(IncLocalInt(i));
						var nrzeroes:int = __cint(i-startpos);
						var n:int;
						if ( nrzeroes >= 16 ) {
							n = nrzeroes >> 4;
							for (var nrmarker:int=1; nrmarker <= n; ++nrmarker) {
								JPGEncoderMacro.writeBitsPtr( M16zeroes_ptr, bytenew, bytepos, _baddr );
							}
							nrzeroes = (nrzeroes&0xF);
						}
						n = __cint(32767 + Memory.readInt(_du_ptr+(i<<2)));
						z1 = __cint( HTAC_ptr + (((nrzeroes<<4) + Memory.readInt(_cat_ptr+(n<<2))) << 3) );
						JPGEncoderMacro.writeBitsPtr( z1, bytenew, bytepos, _baddr );

						z1 = __cint( _bit_ptr + (n<<3));
						JPGEncoderMacro.writeBitsPtr( z1, bytenew, bytepos, _baddr );

						__asm(IncLocalInt(i));
					}
					if ( end0pos != 63 ) {
						JPGEncoderMacro.writeBitsPtr( EOB_ptr, bytenew, bytepos, _baddr );
					}
					
					__asm('breakPass:');
					DCY = DC;
					
					// ----------------------
					// ----------------------
					
					//DCU = processDU(UDUBlock, fdtbl_UVList, DCU, UVDC_HT, UVAC_HT);
					CDU = UDUBlock;
					fdtbl = fdtbl_UVList;
					DC = DCU;
					
					HTDC_ptr = UVDC_HT_ptr;
					HTAC_ptr = UVAC_HT_ptr;
					EOB_ptr = __cint(HTAC_ptr + (0x00<<3));
					M16zeroes_ptr = __cint(HTAC_ptr + (0xF0<<3));
		
					//var DU_DCT:IntLL8x8 = fDCTQuant(CDU, fdtbl);
					// fDCTQuant(data:IntLL8x8, fdtbl:IntLL):IntLL8x8 
					/* Pass 1: process rows. */
					/* Note results are scaled up by sqrt(8) compared to a true DCT; */
					/* furthermore, we scale the results by 2**2. */
					row = CDU;
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
					col = CDU;
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
					dataOff = CDU;
					for (i=0; i<64;) {
						// Apply the quantization and scaling factor & Round to nearest integer
						qval = fdtbl.data;
						fdtbl = fdtbl.next;
						temp = dataOff.data;
						temp = __cint( temp + ( 1 - ( int( temp < 0 ) << 1 )) * ( qval >> 1 ) );
						dataOff.data = __cint( temp / qval );
						dataOff = dataOff.next;
						__asm(IncLocalInt(i));
					}
					DU_DCT = CDU;
					
					//-----------------------------------
					
					//ZigZag reorder
					ZigZag = ZigZagList;					
					for (i=0;i<64;) {
						Memory.writeInt( DU_DCT.data, __cint(_du_ptr + (ZigZag.data<<2)));
						ZigZag = ZigZag.next;
						DU_DCT = DU_DCT.next;
						__asm(IncLocalInt(i));
					}
					
					Diff = __cint(Memory.readInt(_du_ptr) - DC);
					DC = Memory.readInt(_du_ptr);
					
					//Encode DC
					if (Diff==0) {
						JPGEncoderMacro.writeBitsPtr(HTDC_ptr, bytenew, bytepos, _baddr);
					} else {
						i = __cint(32767+Diff);
						z1 = i << 2;
						z2 = __cint(HTDC_ptr+(Memory.readInt(_cat_ptr+z1)<<3));
						JPGEncoderMacro.writeBitsPtr(z2, bytenew, bytepos, _baddr);

						z1 =  __cint( _bit_ptr + (i<<3));
						JPGEncoderMacro.writeBitsPtr(z1, bytenew, bytepos, _baddr );
					}
					//Encode ACs
					end0pos = 63;
					while((end0pos>0)&&(Memory.readInt(__cint(_du_ptr+(end0pos<<2)))==0)) __asm(DecLocalInt(end0pos));//--end0pos;
					if ( end0pos == 0) {
						JPGEncoderMacro.writeBitsPtr( EOB_ptr, bytenew, bytepos, _baddr );
						
						__asm(Jump('breakPass2'));
					}
					i = 1;

					while ( i <= end0pos ) {
						startpos = i;
						while((Memory.readInt(__cint(_du_ptr+(i<<2)))==0) && (i<=end0pos)) __asm(IncLocalInt(i));
						nrzeroes = __cint(i-startpos);
						if ( nrzeroes >= 16 ) {
							n = nrzeroes >> 4;
							for (nrmarker=1; nrmarker <= n; ++nrmarker) {
								JPGEncoderMacro.writeBitsPtr( M16zeroes_ptr, bytenew, bytepos, _baddr );
							}
							nrzeroes = (nrzeroes&0xF);
						}
						n = __cint(32767 + Memory.readInt(_du_ptr+(i<<2)));
						z1 = __cint( HTAC_ptr + (((nrzeroes<<4) + Memory.readInt(_cat_ptr+(n<<2))) << 3) );
						JPGEncoderMacro.writeBitsPtr( z1, bytenew, bytepos, _baddr );

						z1 = __cint( _bit_ptr + (n<<3));
						JPGEncoderMacro.writeBitsPtr( z1, bytenew, bytepos, _baddr );

						__asm(IncLocalInt(i));
					}
					if ( end0pos != 63 ) {
						JPGEncoderMacro.writeBitsPtr( EOB_ptr, bytenew, bytepos, _baddr );
					}
					
					__asm('breakPass2:');
					DCU = DC;
					
					// ----------------------
					// ----------------------
					
					//DCV = processDU(VDUBlock, fdtbl_UVList, DCV, UVDC_HT, UVAC_HT);
					CDU = VDUBlock;
					fdtbl = fdtbl_UVList;
					DC = DCV;
					
					HTDC_ptr = UVDC_HT_ptr;
					HTAC_ptr = UVAC_HT_ptr;
					EOB_ptr = __cint(HTAC_ptr + (0x00<<3));
					M16zeroes_ptr = __cint(HTAC_ptr + (0xF0<<3));
		
					//var DU_DCT:IntLL8x8 = fDCTQuant(CDU, fdtbl);
					// fDCTQuant(data:IntLL8x8, fdtbl:IntLL):IntLL8x8 
					/* Pass 1: process rows. */
					/* Note results are scaled up by sqrt(8) compared to a true DCT; */
					/* furthermore, we scale the results by 2**2. */
					row = CDU;
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
					col = CDU;
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
					dataOff = CDU;
					for (i=0; i<64;) {
						// Apply the quantization and scaling factor & Round to nearest integer
						qval = fdtbl.data;
						fdtbl = fdtbl.next;
						temp = dataOff.data;
						temp = __cint( temp + ( 1 - ( int( temp < 0 ) << 1 )) * ( qval >> 1 ) );
						dataOff.data = __cint( temp / qval );
						dataOff = dataOff.next;
						__asm(IncLocalInt(i));
					}
					DU_DCT = CDU;
					
					//-----------------------------------
					
					//ZigZag reorder
					ZigZag = ZigZagList;					
					for (i=0;i<64;) {
						Memory.writeInt( DU_DCT.data, __cint(_du_ptr + (ZigZag.data<<2)));
						ZigZag = ZigZag.next;
						DU_DCT = DU_DCT.next;
						__asm(IncLocalInt(i));
					}

					Diff = __cint(Memory.readInt(_du_ptr) - DC);
					DC = Memory.readInt(_du_ptr);
					
					//Encode DC
					if (Diff==0) {
						JPGEncoderMacro.writeBitsPtr(HTDC_ptr, bytenew, bytepos, _baddr);
					} else {
						i = __cint(32767+Diff);
						z1 = i << 2;
						z2 = __cint(HTDC_ptr+(Memory.readInt(_cat_ptr+z1)<<3));
						JPGEncoderMacro.writeBitsPtr(z2, bytenew, bytepos, _baddr);

						z1 =  __cint( _bit_ptr + (i<<3));
						JPGEncoderMacro.writeBitsPtr(z1, bytenew, bytepos, _baddr );
					}
					//Encode ACs
					end0pos = 63;
					while((end0pos>0)&&(Memory.readInt(__cint(_du_ptr+(end0pos<<2)))==0)) __asm(DecLocalInt(end0pos));//--end0pos;
					if ( end0pos == 0) {
						JPGEncoderMacro.writeBitsPtr( EOB_ptr, bytenew, bytepos, _baddr );
						
						__asm(Jump('breakPass3'));
					}
					i = 1;

					while ( i <= end0pos ) {
						startpos = i;

						while((Memory.readInt(__cint(_du_ptr+(i<<2)))==0) && (i<=end0pos)) __asm(IncLocalInt(i));
						nrzeroes = __cint(i-startpos);
						if ( nrzeroes >= 16 ) {
							n = nrzeroes >> 4;
							for (nrmarker=1; nrmarker <= n; ++nrmarker) {

								JPGEncoderMacro.writeBitsPtr( M16zeroes_ptr, bytenew, bytepos, _baddr );
							}
							nrzeroes = (nrzeroes&0xF);
						}
						n = __cint(32767 + Memory.readInt(_du_ptr+(i<<2)));

						z1 = __cint( HTAC_ptr + (((nrzeroes<<4) + Memory.readInt(_cat_ptr+(n<<2))) << 3) );
						JPGEncoderMacro.writeBitsPtr( z1, bytenew, bytepos, _baddr );


						z1 = __cint( _bit_ptr + (n<<3));
						JPGEncoderMacro.writeBitsPtr( z1, bytenew, bytepos, _baddr );

						__asm(IncLocalInt(i));
					}
					if ( end0pos != 63 ) {

						JPGEncoderMacro.writeBitsPtr( EOB_ptr, bytenew, bytepos, _baddr );
					}
					
					__asm('breakPass3:');
					DCV = DC;
					// ----------------------
					//
				}
				ypos = __cint(ypos + 8);
			}

			// img.dispose();

			// Do the bit alignment of the EOI marker
			if ( bytepos >= 0 ) {
				//bs = new BitString(__cint((1<<(bytepos+1))-1), __cint(bytepos+1));
				//JPGEncoderMacro.writeBits(bs, bytenew, bytepos, _baddr);
				var numbit:int = __cint(bytepos+1);
				var bn:int = (bytenew << numbit) | __cint((1<<(bytepos+1))-1);
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

			//writeWord(0xFFD9); //EOI
			Memory.writeByte(0xFFD9>>8, _baddr); __asm(IncLocalInt(_baddr));
			Memory.writeByte(0xFFD9, _baddr); __asm(IncLocalInt(_baddr));

			HEAD_BA.position = 0;
			byteout.writeBytes(HEAD_BA);
			byteout.writeBytes(ba_buff, _baddr0, _baddr-_baddr0);
			applicationDomain.domainMemory = oldDomainMemory;
			ba_buff.clear();
			
			return byteout;
		}
	}
}