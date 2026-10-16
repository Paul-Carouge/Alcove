package io.github.paulcarouge.alcove

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.content.IntentCompat

/**
 * The target of "Share to Alcove". It has no UI: it hands the share to the one MainActivity
 * (reusing its task and Flutter engine, so backup and the updater never run twice) and finishes.
 * Without it, a sender that does not ask for a new task would start a second MainActivity, with
 * its own engine, inside the sender's task.
 */
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val share = intent
        // Same anti-redelivery rules as MainActivity: not after a restore, not from recents.
        if (savedInstanceState == null && share != null &&
            share.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY == 0 &&
            (share.action == Intent.ACTION_SEND || share.action == Intent.ACTION_SEND_MULTIPLE)
        ) {
            val forward = Intent(this, MainActivity::class.java).apply {
                action = share.action
                type = share.type
                share.extras?.let { putExtras(it) }
                // The read grant on the shared URIs moves to MainActivity with the clip data.
                clipData = share.clipData ?: clipOf(share)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
            startActivity(forward)
        }
        finish()
    }

    private fun clipOf(share: Intent): ClipData? {
        val uris: List<Uri> = when (share.action) {
            Intent.ACTION_SEND -> listOfNotNull(IntentCompat.getParcelableExtra(share, Intent.EXTRA_STREAM, Uri::class.java))
            else -> IntentCompat.getParcelableArrayListExtra(share, Intent.EXTRA_STREAM, Uri::class.java) ?: emptyList()
        }
        if (uris.isEmpty()) return null
        return ClipData.newRawUri("", uris[0]).apply { uris.drop(1).forEach { addItem(ClipData.Item(it)) } }
    }
}
