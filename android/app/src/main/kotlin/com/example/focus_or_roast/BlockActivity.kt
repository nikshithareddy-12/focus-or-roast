package com.example.focus_or_roast

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.Random

class BlockActivity : Activity() {
    companion object {
        const val TAG = "FocusRoast_BlockAct"
        var isActive: Boolean = false

        val ROAST_MEME_FILES = listOf(
            "image 18.jpg", "image 19.jpg", "image 28.jpg", "image 7.jpg", "image8.jpg",
            "images (1).jpg", "images (2).jpg", "images (3).jpg", "images 10.jpg",
            "images 11.jpg", "images 12.jpg", "images 13.jpg", "images 14.jpg",
            "images 15.jpg", "images 16.jpg", "images 17.jpg", "images 20.jpg",
            "images 21.jpg", "images 22.jpg", "images 23.jpg", "images 29.jpg",
            "images 30.jpg", "images 5.jpg", "images 6.jpg", "images.jpg", "images4.jpg"
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        isActive = true
        val packageName = intent.getStringExtra("package_name") ?: ""
        Log.i("[FocusRoast_Diag]", "BlockActivity onCreate: displayed for package=$packageName")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val subject = intent.getStringExtra("subject") ?: "General"
        val durationMinutes = intent.getIntExtra("duration_minutes", 30)

        val appLabel = getAppLabel(packageName)

        // Root ScrollView
        val scrollView = ScrollView(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#0D0D12"))
            isFillViewport = true
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dpToPx(20), dpToPx(28), dpToPx(20), dpToPx(28))
        }

        // 1. Fire Header Badge
        val headerBadge = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(16), dpToPx(8), dpToPx(16), dpToPx(8))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#26FF5722"))
                cornerRadius = dpToPx(20).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#FF5722"))
            }
        }
        val headerText = TextView(this).apply {
            text = "🔥 FOCUS MODE ACTIVE • $appLabel BLOCKED"
            setTextColor(Color.parseColor("#FF5722"))
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.05f
        }
        headerBadge.addView(headerText)
        container.addView(headerBadge)

        // 2. Meme Image Card (Prominently displayed)
        val memeCard = ImageView(this).apply {
            val imgHeight = dpToPx(250)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                imgHeight
            ).apply {
                setMargins(0, dpToPx(20), 0, dpToPx(16))
            }
            scaleType = ImageView.ScaleType.FIT_CENTER
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#16161F"))
                cornerRadius = dpToPx(18).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#2E2E3E"))
            }
            clipToOutline = true
        }
        container.addView(memeCard)

        // 3. Prominent Roast Punchline
        val punchlineText = TextView(this).apply {
            text = "BRO... BACK TO WORK 😭"
            setTextColor(Color.WHITE)
            textSize = 24f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(8))
        }
        container.addView(punchlineText)

        // 4. Roast Quote from CSV
        val quoteCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(20))
            }
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#181824"))
                cornerRadius = dpToPx(14).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#2C2C40"))
            }
        }

        val quoteTextView = TextView(this).apply {
            text = "Loading roast..."
            setTextColor(Color.parseColor("#FFA726"))
            textSize = 14f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD_ITALIC)
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.2f)
        }
        quoteCard.addView(quoteTextView)
        container.addView(quoteCard)

        // Asynchronously load assets to avoid UI jank and display block screen immediately
        Thread {
            val roastQuote = getRandomRoastQuote()
            val memeBitmap = getRandomRoastMemeBitmap()
            
            runOnUiThread {
                quoteTextView.text = "\"$roastQuote\""
                if (memeBitmap != null) {
                    memeCard.setImageBitmap(memeBitmap)
                } else {
                    memeCard.setImageResource(android.R.drawable.ic_dialog_alert)
                }
            }
        }.start()

        // 5. Subject & Session Pill
        val taskPill = TextView(this).apply {
            text = "📚 Current Focus: $subject"
            setTextColor(Color.parseColor("#8E8AFF"))
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dpToPx(14), dpToPx(6), dpToPx(14), dpToPx(6))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1E1D38"))
                cornerRadius = dpToPx(12).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dpToPx(20))
            }
        }
        container.addView(taskPill)

        // 6. Action Buttons
        // Button 1: RETURN TO FOCUS (Prominent primary button)
        val returnButton = Button(this).apply {
            text = "🎯 RETURN TO FOCUS"
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.04f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(54)
            ).apply {
                setMargins(0, 0, 0, dpToPx(12))
            }
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#FF5722"))
                cornerRadius = dpToPx(16).toFloat()
            }
            setOnClickListener {
                returnToFocusApp(false, subject)
            }
        }
        container.addView(returnButton)

        // Button 2: Quick AI Challenge
        val quizButton = Button(this).apply {
            text = "⚡ Quick AI Quiz Challenge"
            setTextColor(Color.parseColor("#00E676"))
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(48)
            )
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#14261B"))
                cornerRadius = dpToPx(14).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#00E676"))
            }
            setOnClickListener {
                returnToFocusApp(true, subject)
            }
        }
        container.addView(quizButton)

        scrollView.addView(container)
        setContentView(scrollView)
    }

    override fun onResume() {
        super.onResume()
        isActive = true
        Log.d(TAG, "BlockActivity onResume, isActive = true")
    }

    override fun onPause() {
        super.onPause()
        isActive = false
        Log.d(TAG, "BlockActivity onPause, isActive = false")
    }

    override fun onDestroy() {
        isActive = false
        Log.d(TAG, "BlockActivity onDestroy, isActive = false")
        super.onDestroy()
    }

    override fun onBackPressed() {
        // Prevent dropping back into the blocked distraction app
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    private fun returnToFocusApp(openQuiz: Boolean, subject: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_quiz", openQuiz)
            putExtra("subject", subject)
        }
        startActivity(intent)
        finish()
    }

    private fun getAppLabel(pkgName: String): String {
        if (pkgName.isEmpty()) return "Distraction App"
        return try {
            val pm = packageManager
            val info = pm.getApplicationInfo(pkgName, 0)
            pm.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            pkgName.split('.').lastOrNull()?.replaceFirstChar { it.uppercase() } ?: "Distraction App"
        }
    }

    private fun getRandomRoastQuote(): String {
        val paths = listOf("flutter_assets/assets/data/roast_memes.csv", "assets/data/roast_memes.csv")
        for (path in paths) {
            try {
                val inputStream = assets.open(path)
                val reader = BufferedReader(InputStreamReader(inputStream))
                val lines = mutableListOf<String>()
                var line: String? = reader.readLine()
                while (line != null) {
                    val trimmed = line.trim()
                    if (trimmed.isNotEmpty()) {
                        val parts = trimmed.split('|')
                        if (parts.size >= 5) {
                            lines.add(parts[4].trim())
                        } else if (parts.size == 1) {
                            lines.add(parts[0].trim())
                        }
                    }
                    line = reader.readLine()
                }
                reader.close()
                if (lines.isNotEmpty()) {
                    val rand = Random()
                    return lines[rand.nextInt(lines.size)]
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not load roast quote from $path: ${e.message}")
            }
        }
        return "You really tried to open this during focus mode? 😂 Back to work!"
    }

    private fun getRandomRoastMemeBitmap(): Bitmap? {
        val dirs = listOf("flutter_assets/assets/images/roast", "assets/images/roast")
        for (dir in dirs) {
            try {
                var candidateFiles = assets.list(dir)?.filter {
                    it.endsWith(".jpg") || it.endsWith(".png") || it.endsWith(".webp")
                }
                if (candidateFiles.isNullOrEmpty()) {
                    candidateFiles = ROAST_MEME_FILES
                }
                val rand = Random()
                val chosenFile = candidateFiles[rand.nextInt(candidateFiles.size)]
                val stream = assets.open("$dir/$chosenFile")
                val bitmap = BitmapFactory.decodeStream(stream)
                stream.close()
                if (bitmap != null) {
                    return bitmap
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not load roast meme image from $dir: ${e.message}")
            }
        }
        return null
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
