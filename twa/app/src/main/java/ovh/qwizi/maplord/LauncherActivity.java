package ovh.qwizi.maplord;

import android.net.Uri;
import android.os.Bundle;
import androidx.browser.customtabs.CustomTabsIntent;
import androidx.browser.trusted.TrustedWebActivityIntentBuilder;
import androidx.activity.ComponentActivity;

public class LauncherActivity extends ComponentActivity {
    private static final Uri LAUNCH_URI =
            Uri.parse("https://maplord.qwizi.ovh/dashboard");

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        TrustedWebActivityIntentBuilder builder =
                new TrustedWebActivityIntentBuilder(LAUNCH_URI)
                        .setNavigationBarColor(0xFF0A0A0A)
                        .setToolbarColor(0xFF0A0A0A);

        CustomTabsIntent customTabsIntent = builder.buildCustomTabsIntent();
        customTabsIntent.launchUrl(this, LAUNCH_URI);

        finish();
    }
}
