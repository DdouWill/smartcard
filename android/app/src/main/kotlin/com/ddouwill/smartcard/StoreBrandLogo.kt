package com.ddouwill.smartcard

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface

/**
 * Android App Widget 用的品牌 logo badge 產生器。
 *
 * Flutter 端會把 storeLogoLabel / storeBrandColor 存進 HomeWidget SharedPreferences；
 * Kotlin 端背景匹配或舊資料缺欄位時，這裡再用 storeName 做 deterministic fallback。
 * 目的：Widget 顯示每張會員卡自己的品牌標記，不再只顯示 SmartCard App icon。
 */
object StoreBrandLogo {
    private const val DEFAULT_COLOR = "#2196F3"

    private data class BrandSpec(
        val keywords: List<String>,
        val label: String,
        val colorHex: String
    )

    private val knownSpecs = listOf(
        BrandSpec(listOf("7-eleven", "7-11", "711", "小七"), "7", "FFEE4422"),
        BrandSpec(listOf("全家", "familymart", "family mart"), "全家", "FF006B3C"),
        BrandSpec(listOf("萊爾富", "hi-life", "hilife"), "萊", "FF0057A8"),
        BrandSpec(listOf("ok 超商", "ok超商", "ok"), "OK", "FF1B5E20"),
        BrandSpec(listOf("全聯", "pxmart"), "PX", "FFCC0000"),
        BrandSpec(listOf("家樂福", "carrefour"), "C", "FF0063B8"),
        BrandSpec(listOf("大潤發", "rt-mart", "rt mart"), "RT", "FFD71920"),
        BrandSpec(listOf("大全聯", "mega pxmart"), "PX", "FFCC0000"),
        BrandSpec(listOf("好市多", "costco"), "COST", "FF005DAA"),
        BrandSpec(listOf("美廉社", "simple mart"), "美", "FF2E7D32"),
        BrandSpec(listOf("頂好", "wellcome"), "W", "FF1565C0"),
        BrandSpec(listOf("愛買"), "愛", "FFAA0000"),
        BrandSpec(listOf("屈臣氏", "watsons"), "W", "FF00B5AD"),
        BrandSpec(listOf("康是美", "cosmed"), "康", "FFD32F2F"),
        BrandSpec(listOf("寶雅", "poya"), "POYA", "FF880E4F"),
        BrandSpec(listOf("小三美日"), "小三", "FFE91E63"),
        BrandSpec(listOf("新光三越", "新光"), "新光", "FFB71C1C"),
        BrandSpec(listOf("sogo"), "SOGO", "FFB00020"),
        BrandSpec(listOf("遠東百貨", "遠百"), "遠百", "FF0D47A1"),
        BrandSpec(listOf("微風"), "微風", "FF6A1B9A"),
        BrandSpec(listOf("統一時代"), "時代", "FF37474F"),
        BrandSpec(listOf("三井", "mitsui"), "M", "FF0D47A1"),
        BrandSpec(listOf("lalaport"), "La", "FF005BAC"),
        BrandSpec(listOf("漢神", "hanshin"), "漢神", "FF7B1FA2"),
        BrandSpec(listOf("gu"), "GU", "FF0D47A1"),
        BrandSpec(listOf("uniqlo", "優衣庫"), "UQ", "FFE60012"),
        BrandSpec(listOf("muji", "無印"), "MUJI", "FF7F0019"),
        BrandSpec(listOf("小北"), "小北", "FFFF8F00"),
        BrandSpec(listOf("大創", "daiso"), "大創", "FFEC008C"),
        BrandSpec(listOf("九乘九", "9x9"), "9x9", "FFFF9800"),
        BrandSpec(listOf("振宇"), "振宇", "FFFFA000"),
        BrandSpec(listOf("誠品"), "誠品", "FF2E2E2E"),
        BrandSpec(listOf("金石堂"), "金石", "FFD32F2F"),
        BrandSpec(listOf("路易莎", "louisa"), "L", "FF5D4037"),
        BrandSpec(listOf("星巴克", "starbucks"), "★", "FF00704A"),
        BrandSpec(listOf("cama"), "cama", "FF6D4C41"),
        BrandSpec(listOf("摩斯", "mos"), "MOS", "FF2E7D32"),
        BrandSpec(listOf("麥當勞", "mcdonald"), "M", "FFDA1F1F"),
        BrandSpec(listOf("肯德基", "kfc"), "KFC", "FFB71C1C"),
        BrandSpec(listOf("八方"), "八方", "FFEF6C00"),
        BrandSpec(listOf("全國電子"), "全國", "FF0D47A1"),
        BrandSpec(listOf("燦坤"), "燦坤", "FFFF6F00"),
        BrandSpec(listOf("台灣高鐵", "高鐵", "thsr"), "高鐵", "FFFF8F00"),
        BrandSpec(listOf("中油", "cpc"), "CPC", "FF1565C0"),
        BrandSpec(listOf("台塑", "fpcc"), "台塑", "FF2E7D32"),
        BrandSpec(listOf("金門良金牧場", "良金"), "良金", "FF6D4C41"),
        BrandSpec(listOf("澎湖免稅"), "澎湖", "FF00838F")
    )

    fun renderBitmap(
        storeName: String,
        logoLabel: String? = null,
        brandColorHex: String? = null,
        cardColorHex: String? = null,
        sizePx: Int = 96
    ): Bitmap {
        val spec = findKnownSpec(storeName)
        val label = sanitizeLabel(logoLabel)
            ?: spec?.label
            ?: fallbackLabel(storeName)
        val bgColor = parseColor(brandColorHex)
            ?: parseColor(spec?.colorHex)
            ?: parseColor(cardColorHex)
            ?: parseColor(DEFAULT_COLOR)
            ?: Color.rgb(33, 150, 243)
        val textColor = readableTextColor(bgColor)

        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val radius = sizePx / 2f

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = bgColor
            style = Paint.Style.FILL
        }
        canvas.drawCircle(radius, radius, radius, fillPaint)

        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(42, 255, 255, 255)
            style = Paint.Style.STROKE
            strokeWidth = sizePx * 0.04f
        }
        canvas.drawCircle(radius, radius, radius - borderPaint.strokeWidth / 2, borderPaint)

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
            textSize = textSizeFor(label, sizePx)
        }

        val bounds = Rect()
        textPaint.getTextBounds(label, 0, label.length, bounds)
        val y = radius - bounds.exactCenterY()
        canvas.drawText(label, radius, y, textPaint)

        return bitmap
    }

    private fun findKnownSpec(storeName: String): BrandSpec? {
        val lower = storeName.trim().lowercase()
        if (lower.isBlank()) return null
        return knownSpecs.firstOrNull { spec ->
            spec.keywords.any { keyword ->
                lower == keyword.lowercase() ||
                    lower.contains(keyword.lowercase()) ||
                    keyword.lowercase().contains(lower)
            }
        }
    }

    private fun sanitizeLabel(label: String?): String? {
        val trimmed = label?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        return takeCodePoints(trimmed, 4)
    }

    private fun takeCodePoints(value: String, maxCount: Int): String {
        val builder = StringBuilder()
        var index = 0
        var count = 0
        while (index < value.length && count < maxCount) {
            val codePoint = value.codePointAt(index)
            builder.appendCodePoint(codePoint)
            index += Character.charCount(codePoint)
            count++
        }
        return builder.toString()
    }

    private fun fallbackLabel(storeName: String): String {
        val trimmed = storeName.trim()
        if (trimmed.isBlank()) return "卡"

        val cjk = Regex("[\\u4E00-\\u9FFF]").findAll(trimmed).take(2).joinToString("") {
            it.value
        }
        if (cjk.isNotEmpty()) return cjk

        val asciiWords = Regex("[A-Za-z0-9]+").findAll(trimmed).map { it.value }.toList()
        if (asciiWords.isNotEmpty()) {
            val first = asciiWords.first().uppercase()
            if (first.length <= 4) return first
            if (asciiWords.size > 1) {
                return asciiWords.take(4).joinToString("") { it.first().uppercaseChar().toString() }
            }
            return first.take(4)
        }

        return sanitizeLabel(trimmed) ?: "卡"
    }

    private fun parseColor(colorHex: String?): Int? {
        val raw = colorHex?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val normalized = when {
            raw.startsWith("#") -> raw
            raw.matches(Regex("[0-9A-Fa-f]{6}")) -> "#$raw"
            raw.matches(Regex("[0-9A-Fa-f]{8}")) -> "#$raw"
            else -> return null
        }
        return try {
            Color.parseColor(normalized)
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    private fun readableTextColor(color: Int): Int {
        val luminance = (0.299 * Color.red(color) +
            0.587 * Color.green(color) +
            0.114 * Color.blue(color)) / 255.0
        return if (luminance > 0.62) Color.rgb(35, 35, 35) else Color.WHITE
    }

    private fun textSizeFor(label: String, sizePx: Int): Float {
        val codePointCount = label.codePointCount(0, label.length)
        return when {
            codePointCount <= 1 -> sizePx * 0.52f
            codePointCount == 2 -> sizePx * 0.40f
            codePointCount == 3 -> sizePx * 0.32f
            else -> sizePx * 0.25f
        }
    }
}
