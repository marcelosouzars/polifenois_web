import 'package:flutter/material.dart';
import 'login_web.dart'; 

void main() {
  runApp(MaterialApp(
    title: 'Vetix Polifenóis',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(primarySwatch: Colors.blue),
    home: LoginWeb(), 
  ));
}