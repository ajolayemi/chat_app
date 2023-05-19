import 'package:chat_app/widgets/user_image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

final _firebase = FirebaseAuth.instance;

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _isLogin = true;
  var _showPassword = false;
  File? _selectedImage;
  var _isAuthenticating = false;

  void _submit() async {
    final isValid = _formKey.currentState?.saveAndValidate(
          autoScrollWhenFocusOnInvalid: false,
          focusOnInvalid: false,
        ) ??
        false;
    if (!isValid) {
      return;
    }

    if (!_isLogin && _selectedImage == null) {
      return;
    }

    final currentFormVals = _formKey.currentState!.value;
    final emailAddress = currentFormVals['email'];
    final password = currentFormVals['password'];
    final username = currentFormVals['username'];

    try {
      setState(() => _isAuthenticating = true);
      if (_isLogin) {
        await _firebase.signInWithEmailAndPassword(
            email: emailAddress, password: password);
      } else {
        final userCredentials = await _firebase.createUserWithEmailAndPassword(
          email: emailAddress,
          password: password,
        );

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_images')
            .child('${userCredentials.user!.uid}.jpg');
        await storageRef.putFile(_selectedImage!);
        final imageUrl = await storageRef.getDownloadURL();

        final dataForFirestore = {
          'username': username,
          'email': emailAddress,
          'image_url': imageUrl
        };
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredentials.user!.uid)
            .set(dataForFirestore);
      }
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        debugPrint('User exists');
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Authentication failed'),
        ),
      );
      setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(
                  top: 30,
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                width: 200,
                child: Image.asset('assets/images/chat.png'),
              ),
              Card(
                margin: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FormBuilder(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isLogin)
                            UserImagePicker(
                              onPickImage: (pickedImage) =>
                                  _selectedImage = pickedImage,
                            ),
                          FormBuilderTextField(
                            name: 'email',
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            validator: FormBuilderValidators.compose(
                              [
                                FormBuilderValidators.required(),
                                FormBuilderValidators.email(),
                              ],
                            ),
                          ),
                          if (!_isLogin)
                            FormBuilderTextField(
                              name: 'username',
                              validator: FormBuilderValidators.compose(
                                [FormBuilderValidators.required()],
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Username',
                              ),
                              enableSuggestions: false,
                            ),
                          FormBuilderTextField(
                            name: 'password',
                            validator: FormBuilderValidators.compose(
                              [
                                FormBuilderValidators.required(),
                                (value) {
                                  if (value != null
                                      ? value.length < 6
                                      : false) {
                                    return 'Password must be greater than 6';
                                  }
                                  return null;
                                }
                              ],
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                    () => _showPassword = !_showPassword),
                                icon: Icon(!_showPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              ),
                            ),
                            obscureText: !_showPassword,
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          if (_isAuthenticating)
                            const CircularProgressIndicator(),
                          if (!_isAuthenticating)
                            ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer),
                              child: Text(_isLogin ? 'Login' : 'Signup'),
                            ),
                          if (!_isAuthenticating)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                });
                              },
                              child: Text(_isLogin
                                  ? 'Create an account'
                                  : 'I already have an account'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
