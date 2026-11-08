package com.example.budget.core.charges

import com.example.budget.core.Tint

enum class ChargeCategory(val raw: String, val label: String, val emoji: String, val tint: Tint) {
    HOUSING("housing", "Housing", "🏠", Tint.PEACH),
    UTILITIES("utilities", "Utilities", "💡", Tint.BUTTER),
    INSURANCE("insurance", "Insurance", "🛡️", Tint.SKY),
    SUBSCRIPTIONS("subscriptions", "Subscriptions", "📺", Tint.LAVENDER),
    TRANSPORT("transport", "Transport", "🚗", Tint.SKY),
    HEALTH("health", "Health", "💊", Tint.PINK),
    LOANS("loans", "Loans", "🏦", Tint.BUTTER),
    LEISURE("leisure", "Leisure", "🎮", Tint.MINT),
    OTHER("other", "Other", "🌸", Tint.PINK);

    companion object {
        val all: List<ChargeCategory> = entries.toList()
        fun fromRaw(raw: String): ChargeCategory = entries.firstOrNull { it.raw == raw } ?: OTHER
    }
}

/** A charge paid every month (rent, subscriptions, insurance...). */
data class FixedCharge(
    val id: Long = 0,
    val title: String,
    val amount: Double,
    val category: ChargeCategory = ChargeCategory.OTHER,
    /** No longer shown or edited; kept so stored data opens unchanged. */
    val dayOfMonth: Int = 1,
    /** Empty: the category's emoji. */
    val emoji: String = "",
) {
    val displayEmoji: String get() = emoji.ifEmpty { category.emoji }
}
