import 'package:flutter/material.dart';
import 'package:fyp_project/auth/login_screen.dart';
import 'package:fyp_project/auth/signup_screen.dart';
import 'package:fyp_project/theme/theme.dart';
import 'package:fyp_project/widget/custom_scaffold.dart';
import 'package:fyp_project/widget/welcome_button.dart';

class WelcomeScreen extends StatelessWidget{
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context){
    return CustomScaffold(
      child: Column(
        children: [
          Flexible(
              flex: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 60.0,
                ),
                child: Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      children: [
                        TextSpan(
                            text: 'Hi! Let’s save some food today.\n',
                            style: TextStyle(
                              fontSize: 32.0,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                              color: Colors.white,
                            )),
                        TextSpan(
                            text:
                            '\nSave food. Save money. Save the planet.',
                            style: TextStyle(
                              fontSize: 20,
                                fontFamily: 'Poppins',
                              color: Colors.white
                              // height: 0,
                            ))
                      ],
                    ),
                  ),
                ),
              )),
          Flexible(
            flex: 1,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Row(
                children: [
                  Expanded(child: WelcomeButton(
                    buttonText: 'Sign in',
                    onTap:LoginScreen(),
                    color: Colors.transparent,
                    textColor: Colors.white,
                  )
                  ),
                  Expanded(child: WelcomeButton(
                    buttonText: 'Sign Up',
                    onTap:SignUpScreen(),
                    color: Colors.white,
                    textColor: lightColorScheme.primary,
                  )
                  ),
                ],
              ),
            )
          ),

        ],
      )
    );
  }
}