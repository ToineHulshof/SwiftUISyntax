//
//  MainActivityText.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 15/04/2020.
//  Copyright c 2020 Toine Hulshof. All rights reserved.
//

import Foundation

extension StructTranslator {
    static let sceneDelegateString = """
    package //Change this to your package name

    import android.app.Application
    import android.content.Context
    import android.os.Bundle
    import androidx.appcompat.app.AppCompatActivity
    import androidx.compose.Composable
    import androidx.compose.Model
    import androidx.ui.animation.Crossfade
    import androidx.ui.core.ContextAmbient
    import androidx.ui.core.Modifier
    import androidx.ui.core.setContent
    import androidx.ui.foundation.Icon
    import androidx.ui.foundation.Text
    import androidx.ui.graphics.ScaleFit
    import androidx.ui.material.*
    import androidx.ui.material.icons.Icons
    import androidx.ui.material.icons.filled.ArrowBack
    import androidx.ui.res.imageResource

    class MainActivity : AppCompatActivity() {
        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            setContent {
                MaterialTheme {
                    Crossfade(Navigation.currentScreen) { screen ->
                        when (screen) {
                            // This is the main screen defined in SceneDelegate.swift (default is ContentView())
                            is Screen.Home -> CategoryHome()
                            // Add custom screens
                            // is Screen.LandmarkList -> NavigationLink(title = "Landmarks") { LandmarkList() }
                            // is Screen.Landmark -> NavigationLink(title = screen.landmark.name) { LandmarkDetail(landmark = screen.landmark) }
                        }
                    }
                }
            }
        }
    }

    // add
    // <application
    //        android:name=".MyApplication"
    // in AndroidManifest.xml
    class MyApplication : Application() {
        override fun onCreate() {
            super.onCreate()
            context = applicationContext
        }

        companion object {
            private var context: Context? = null
            val appContext: Context?
                get() = context
        }
    }

    sealed class Screen {
        object Home : Screen()
        // Add customs screens
        // object LandmarkList : Screen()
        // data class Landmark(val landmark: Landmark) : Screen()
    }

    @Model
    object Navigation {
        var currentScreen: Screen = Screen.Home
    }

    fun navigateTo(destination: Screen) {
        Navigation.currentScreen = destination
    }

    @Composable
    fun NavigationLink(title: String = "", destination: @Composable() () -> Unit) {
        Scaffold(
            topAppBar = {
                TopAppBar(
                    title = {
                        Text(title)
                    },
                    navigationIcon = {
                        IconButton(onClick = { navigateTo(Screen.Home) }) {
                            Icon(Icons.Filled.ArrowBack)
                        }
                    }
                )
            },
            bodyContent = {
                destination()
            }
        )
    }

    @Composable
    fun Image(name: String, modifier: Modifier = Modifier.None, scaleFit: ScaleFit = ScaleFit.Fit) {
        androidx.ui.foundation.Image(
            imageResource(
                ContextAmbient.current.resources.getIdentifier(
                    name,
                    "drawable",
                    ContextAmbient.current.packageName
                )
            ),
            modifier = modifier,
            scaleFit = scaleFit
        )
    }
    """
}
