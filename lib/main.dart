//
// MAIN.DART (WEB)
//
import 'package:flutter/material.dart';
import 'login_web.dart'; 

void main() {
  runApp(MaterialApp(
    title: 'Polifenóis',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(primarySwatch: Colors.blue),
    home: LoginWeb(), 
  ));
}