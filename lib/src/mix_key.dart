import 'dart:math';

/// Mix key
/// Use for byte confusion
class MixKey {
	factory MixKey.random() => MixKey(Random().nextInt(0xFFFFFFFF));
	MixKey(int baseKey)
		:baseKey = baseKey,
			keyList = [
				(baseKey & 0xFF),
				((baseKey >> 8) & 0xFF),
				((baseKey >> 16) & 0xFF),
				((baseKey >> 24) & 0xFF),
			];
	
	final int baseKey;
	final List<int> keyList;
	
	int mixByte(int byte, {int beginKeyIndex = 0}) {
		final j = beginKeyIndex == null ? 0 : beginKeyIndex % 4;
		return keyList[j] ^ byte;
	}
	
	List<int> mixByteList(List<int> byteList, {bool modifyOriginList = true, int beginKeyIndex = 0}) {
		if (byteList == null) {
			return null;
		}
		final byteLength = byteList.length;
		var j = beginKeyIndex == null ? 0 : beginKeyIndex % 4;
		if (modifyOriginList) {
			for (var i = 0; i < byteLength; i ++) {
				byteList[i] ^= keyList[j];
				j ++;
				if(j == 4) {
					j = 0;
				}
			}
		}
		else {
			final newList = <int>[];
			for (var i = 0; i < byteLength; i ++) {
				newList.add(byteList[i] ^ keyList[j]);
				j ++;
				if(j == 4) {
					j = 0;
				}
			}
			byteList = newList;
		}
		return byteList;
	}
	
	@override
	String toString() => keyList.toString();
}