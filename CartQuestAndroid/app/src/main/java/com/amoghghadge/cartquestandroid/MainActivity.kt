package com.amoghghadge.cartquestandroid

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.amoghghadge.cartquestandroid.ui.auth.AuthState
import com.amoghghadge.cartquestandroid.ui.auth.LoginScreen
import com.amoghghadge.cartquestandroid.ui.auth.LoginViewModel
import com.amoghghadge.cartquestandroid.ui.navigation.AppNavigation
import com.amoghghadge.cartquestandroid.ui.theme.CartQuestAndroidTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CartQuestAndroidTheme {
                val loginViewModel: LoginViewModel = viewModel()
                val authState by loginViewModel.authState.collectAsState()

                when (authState) {
                    is AuthState.Unauthenticated, is AuthState.Error -> {
                        LoginScreen(viewModel = loginViewModel)
                    }
                    is AuthState.Loading -> {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator()
                        }
                    }
                    is AuthState.Authenticated -> {
                        AppNavigation(onLoggedOut = { loginViewModel.signOut() })
                    }
                }
            }
        }
    }
}
