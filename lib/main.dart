import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:qr/qr.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBUpMrSvpXFHS2aPujkN5mIE7nFtfaIH8g",
      appId: "1:775644063426:web:48df87e2c988a97dd6fd5b",
      messagingSenderId: "775644063426",
      projectId: "G-NLLQJS1ZC8",
    ),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTP Example',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OTP Example'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OtpScreen()),
            );
          },
          child: Text('Verify Phone Number'),
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _verificationId = '';

  Future<void> _verifyPhoneNumber() async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneNumberController.text,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          print(
              'Phone number automatically verified and user signed in: ${_auth.currentUser!.uid}');
          await _collectAndSaveLoginDetails();
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Phone number verification failed: $e');
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Code sent to ${_phoneNumberController.text}');
          _verificationId = verificationId;
          print(_verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      print('Error during phone number verification: $e');
    }
  }

  Future<void> _verifyOtp() async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text,
      );

      await _auth.signInWithCredential(credential);
      print('User signed in: ${_auth.currentUser!.uid}');
      await _collectAndSaveLoginDetails();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen()),
      );
    } catch (e) {
      print('Error during OTP verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error during OTP verification: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OTP Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _phoneNumberController,
              decoration: InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _verifyPhoneNumber,
              child: Text('Send OTP'),
            ),
            SizedBox(height: 32.0),
            TextField(
              controller: _otpController,
              decoration: InputDecoration(labelText: 'OTP'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _verifyOtp,
              child: Text('Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }
}

class QrCodeWidget extends StatelessWidget {
  final String data;

  const QrCodeWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      color: Colors.black,
      emptyColor: Colors.white,
      gapless: false,
    );

    return CustomPaint(
      size: Size.square(300),
      painter: qrPainter,
    );
  }
}

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Random Number: ${Random().nextInt(1000) + 1}',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 16),
            QrCodeWidget(data: '${Random().nextInt(1000) + 1}'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Upload the image to Firebase Storage
                final imageUrl = await _uploadImage();

                // Save the generated number and the image URL to Firebase Database
                await _saveDataToDatabase(imageUrl);
              },
              child: Text('Upload Image'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadImage() async {
    // Load the image from a file
    final bytes = await rootBundle.load('assets/my_image.png');
    final image = img.decodeImage(bytes.buffer.asUint8List());

    if (image == null) {
      throw Exception('Failed to decode image.');
    }

    // Encode the image to PNG format
    final pngBytes = img.encodePng(image);

    // Upload the image to Firebase Storage
    final ref =
    FirebaseStorage.instance.ref().child('images').child('image.png');
    final uploadTask = ref.putData(pngBytes); // Use pngBytes directly

    final snapshot = await uploadTask;
    final imageUrl = await snapshot.ref.getDownloadURL();

    return imageUrl;
  }

  Future<void> _saveDataToDatabase(String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = {
        'number': Random().nextInt(1000) + 1,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('data')
          .doc(user.uid)
          .set(data);
    }
  }
}

Future<void> _collectAndSaveLoginDetails() async {
  try {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final User? user = _auth.currentUser;

    if (user != null) {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      final ipAddress = response.body;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latitude = position.latitude;
      final longitude = position.longitude;

      await FirebaseFirestore.instance
          .collection('login_details')
          .doc(user.uid)
          .set({
        'ip_address': ipAddress,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('Login details saved successfully.');
    } else {
      print('User not signed in.');
    }
  } catch (e) {
    print('Error collecting and saving login details: $e');
  }
}
