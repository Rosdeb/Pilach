import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool isInitialized = false;

  static Future<void> _initSignIn() async {
    if (!isInitialized) {
      await _googleSignIn.initialize();
      isInitialized = true;

    }
  }

  //<-----> Returns a Map with user data and tokens <----->//
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {

      await _initSignIn();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      final idToken = googleUser.authentication.idToken;

      if (idToken == null) {
        throw Exception("ID Token is null");
      }
      //-----> Get access token using authorization client <------//
      final authorizationClient = googleUser.authorizationClient;
      GoogleSignInClientAuthorization? authorization =
      await authorizationClient.authorizationForScopes(['email', 'profile']);
      String? accessToken = authorization?.accessToken;

      // If access token is null, try to authorize again
      if (accessToken == null) {
        authorization = await authorizationClient.authorizeScopes(['email', 'profile']);
        accessToken = authorization.accessToken;
      }

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );


      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);



      final User? user = userCredential.user;

      if (user != null) {

        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          await userDoc.set({
            'uid': user.uid,
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'photoURL': user.photoURL ?? '',
            'provider': 'google',
            'createdAt': FieldValue.serverTimestamp(),
          });

        } else {

        }

        // Return all data including tokens
        return {
          'userCredential': userCredential,
          'user': user,
          'idToken': idToken,
          'accessToken': accessToken,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'uid': user.uid,
          'emailVerified': user.emailVerified,
          'phoneNumber': user.phoneNumber,
        };
      }

      return null;

    } on GoogleSignInException catch (e) {

      if (e.code == GoogleSignInExceptionCode.canceled) {

        return null;
      }
      rethrow;
    } catch (e) {

      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();

    } catch (e) {

      rethrow;
    }
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

}