import 'dart:async';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:transport/src/isolate_runner.dart';




/// RSA Hand shake encrypt
class RSAHandShakeEncrypt {
	factory RSAHandShakeEncrypt() => const RSAHandShakeEncrypt._();
	const RSAHandShakeEncrypt._();

	@override
	Future<String> encode(RSAPublicKey publicKey, String encryptData) {
		return IsolateRunner.execute(
			_RSAHandShakeBundle(
				message: encryptData,
				publicKey: publicKey
			),
			runner: _encodeBase64
		);
	}
	
	@override
	Future<String> decode(RSAPrivateKey privateKey, String decryptData) {
		return IsolateRunner.execute(
			_RSAHandShakeBundle(
				message: decryptData,
				privateKey: privateKey
			),
			runner: _decodeBase64
		);
	}
}

class _RSAHandShakeBundle {
    _RSAHandShakeBundle({this.message, this.publicKey, this.privateKey});
	final String message;
	final RSAPublicKey publicKey;
	final RSAPrivateKey privateKey;
}

FutureOr<String> _encodeBase64(_RSAHandShakeBundle bundle) {
	final encrypter = Encrypter(RSA(publicKey: bundle.publicKey, privateKey: null));
	return encrypter.encrypt(bundle.message).base64;
}

FutureOr<String> _decodeBase64(_RSAHandShakeBundle bundle) {
	final encrypter = Encrypter(RSA(publicKey: null, privateKey: bundle.privateKey));
	return encrypter.decrypt64(bundle.message);
}