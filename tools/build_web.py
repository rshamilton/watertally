#!/usr/bin/env python3
"""
Builds the static website in web/ (for GitHub Pages at https://rshamilton.github.io/watertally/).

Every page shares one header/footer, so the pages are generated from this file.
Run from the repo root:   python3 tools/build_web.py
Edit the constants below (name, email, dates) and re-run to update every page at once.
"""
import html
import json
import pathlib
import urllib.parse

APP = "Water Tally"
DEVELOPER = "Ryan Hamilton"
EMAIL = "watertally@googlegroups.com"
BASE = "https://rshamilton.github.io/watertally/"
EFFECTIVE = "November 10, 2026"
YEAR = "2026"
BUNDLE = "me.ryham.WaterTally"
APP_STORE_ID = "6814481718"
APP_STORE = f"https://apps.apple.com/us/app/water-tally-drink-tracker/id{APP_STORE_ID}"
REPO = "https://github.com/rshamilton/watertally"
COMPARED_ON = "November 11, 2026"

# One sentence that describes the app the same way everywhere (site, README, llms.txt).
POSITIONING = (f"{APP} is a free, open-source water tracker for iPhone and iPad. Log a drink in one tap, "
               "see your progress toward a daily goal, and keep everything on your device. "
               "No ads, no subscription, no account, and no data collected.")

OUT = pathlib.Path(__file__).resolve().parent.parent / "web"

NAV = [
    ("index.html", "Home"),
    ("privacy.html", "Privacy"),
    ("terms.html", "Terms"),
    ("medical-disclaimer.html", "Medical Disclaimer"),
    ("faq.html", "FAQ"),
    ("support.html", "Support"),
]

# Extra footer-only links.
FOOTER_EXTRA = [("compare.html", "Compare")]

MAILTO = f"mailto:{EMAIL}?subject={urllib.parse.quote(APP + ' Support')}"


def page(filename, title, description, body, wide=False, noindex=False, root_prefix="", head=""):
    nav = "\n".join(
        f'        <li><a href="{root_prefix}{href}"{" aria-current=\"page\"" if href == filename else ""}>{label}</a></li>'
        for href, label in NAV
    )
    footer_links = "\n".join(f'        <li><a href="{root_prefix}{href}">{label}</a></li>' for href, label in NAV + FOOTER_EXTRA)
    robots = '  <meta name="robots" content="noindex">\n' if noindex else ""
    canonical = f"{BASE}{filename}" if filename != "404.html" else BASE
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <meta name="description" content="{html.escape(description)}">
{robots}  <link rel="canonical" href="{canonical}">
  <link rel="icon" type="image/png" href="{root_prefix}assets/favicon.png">
  <link rel="apple-touch-icon" href="{root_prefix}assets/apple-touch-icon.png">
  <meta property="og:type" content="website">
  <meta property="og:title" content="{html.escape(title)}">
  <meta property="og:description" content="{html.escape(description)}">
  <meta property="og:image" content="{BASE}assets/social-card.png">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="apple-itunes-app" content="app-id={APP_STORE_ID}">
{head}
  <meta name="theme-color" content="#0b1724" media="(prefers-color-scheme: dark)">
  <meta name="theme-color" content="#f5f1e8" media="(prefers-color-scheme: light)">
  <link rel="stylesheet" href="{root_prefix}assets/style.css">
</head>
<body>
  <a class="skip-link" href="#content">Skip to content</a>
  <header class="site-header">
    <a class="brand" href="{root_prefix}index.html"><img src="{root_prefix}assets/icon-512.png" alt="" width="38" height="38">{APP}</a>
    <nav aria-label="Main">
      <ul>
{nav}
      </ul>
    </nav>
  </header>
  <main id="content"{' class="wide"' if wide else ''}>
{body}
  </main>
  <footer class="site-footer">
    <div class="inner">
      <ul>
{footer_links}
        <li><a href="{MAILTO}">Contact</a></li>
        <li><a href="{APP_STORE}">App Store</a></li>
        <li><a href="https://github.com/rshamilton/watertally">Source code</a></li>
      </ul>
      <p>&copy; {YEAR} {DEVELOPER}. {APP} is an independent app and is not affiliated with, endorsed by, or sponsored by Apple Inc. Apple, Apple Health, iPhone, iPad, and App Store are trademarks of Apple Inc.</p>
      <p>{APP} is a personal tracking tool, not a medical device. It does not provide medical advice. <a href="{root_prefix}medical-disclaimer.html">Read the medical disclaimer</a>.</p>
    </div>
  </footer>
</body>
</html>
"""


# ---------------------------------------------------------------- Home

HOME = f"""
    <section class="hero">
      <img class="icon" src="assets/icon-512.png" alt="{APP} app icon" width="132" height="132">
      <h1>{APP}</h1>
      <p class="lead">{POSITIONING}</p>
      <a class="badge" href="{APP_STORE}">Download on the App Store</a>
      <p class="muted small">Free. iPhone and iPad, iOS 17 or later. <a href="{REPO}">Open source on GitHub</a>.</p>
    </section>

    <ul class="features">
      <li><h3>One-tap logging</h3><p>Big, friendly buttons for the glasses and bottles you actually use, plus a custom-amount button for everything else. Made a mistake? Undo it right away.</p></li>
      <li><h3>Widgets &amp; Lock Screen</h3><p>Check your progress and log a drink from the Home Screen or Lock Screen without opening the app.</p></li>
      <li><h3>Trends &amp; streaks</h3><p>A calendar, daily history, weekly and monthly charts, and streaks to keep you going.</p></li>
      <li><h3>Optional Apple Health</h3><p>Save your water to Apple Health if you want it alongside your other data. It is off until you turn it on.</p></li>
      <li><h3>Gentle reminders</h3><p>Optional reminders you schedule yourself. They are created on your device and pause once you reach your goal.</p></li>
      <li><h3>Private by design</h3><p>No account. No ads. No analytics. No tracking. Your entries stay on your device, and you can export or delete them any time.</p></li>
    </ul>

    <div class="notice warning" role="note">
      <h2>Please note</h2>
      <p>{APP} is a simple logging tool. It is not a medical device and does not give medical advice. Goals are personal targets you choose. Talk to a qualified healthcare professional about how much fluid is right for you. <a href="medical-disclaimer.html">Read the full medical disclaimer</a>.</p>
    </div>

    <p class="muted">Questions? Read the <a href="faq.html">FAQ</a>, see <a href="compare.html">how {APP} compares</a> with other water trackers, or visit <a href="support.html">Help &amp; Support</a>.</p>
"""

# ---------------------------------------------------------------- Privacy

PRIVACY = f"""
    <h1>Privacy Policy</h1>
    <p class="meta">Effective {EFFECTIVE} &middot; Applies to the {APP} app for iPhone and iPad, its widgets, and this website</p>

    <div class="summary">
      <h2>The short version</h2>
      <ul>
        <li>{APP} has <strong>no account, no ads, no analytics, no tracking, and no third-party SDKs</strong>.</li>
        <li>What you log stays <strong>on your device</strong>. {DEVELOPER} (the developer) does not receive it, because {APP} has no servers.</li>
        <li><strong>Apple Health is optional</strong>. If you turn it on, {APP} reads and writes only <em>Water</em> in Apple Health, on your device.</li>
        <li>You can <strong>export or delete</strong> everything from inside the app.</li>
      </ul>
    </div>

    <h2>Contents</h2>
    <ol class="toc">
      <li><a href="#who">Who is responsible</a></li>
      <li><a href="#stored">What {APP} stores on your device</a></li>
      <li><a href="#collect">What I collect</a></li>
      <li><a href="#health">Apple Health</a></li>
      <li><a href="#notifications">Notifications</a></li>
      <li><a href="#widgets">Widgets and the Lock Screen</a></li>
      <li><a href="#export">Exporting your data</a></li>
      <li><a href="#backups">Device backups</a></li>
      <li><a href="#retention">Retention and deletion</a></li>
      <li><a href="#security">Security</a></li>
      <li><a href="#children">Children</a></li>
      <li><a href="#rights">Your privacy rights</a></li>
      <li><a href="#international">International use</a></li>
      <li><a href="#changes">Changes to this policy</a></li>
      <li><a href="#contact">Contact</a></li>
    </ol>

    <h2 id="who">1. Who is responsible</h2>
    <p>{APP} is published by {DEVELOPER}, an individual developer ("I", "me", "my"). For questions about this policy, contact <a href="{MAILTO}">{EMAIL}</a>.</p>

    <h2 id="stored">2. What {APP} stores on your device</h2>
    <p>To work, {APP} saves the following on your device only:</p>
    <ul>
      <li>the drinks you log: amount, date and time, and the name of the button you used;</li>
      <li>your buttons (names, amounts, colours, order);</li>
      <li>your daily goal, unit (ounces or millilitres), theme colour, and streak counts;</li>
      <li>your reminder settings (if you turn reminders on);</li>
      <li>whether you have completed onboarding and which version of the legal terms you acknowledged, and when.</li>
    </ul>
    <p>This information is kept in {APP}'s private storage and in a shared storage area (an "App Group") that only {APP} and its own widget can read. It is not sent anywhere by {APP}.</p>

    <h2 id="collect">3. What I collect</h2>
    <p><strong>Nothing, through the app.</strong> {APP} does not connect to any server that I run, does not include advertising or analytics code, and does not contain third-party software that collects data. I do not collect, receive, sell, rent, or share the information in Section 2.</p>
    <p>Limited exceptions, all outside the app's own data:</p>
    <ul>
      <li><strong>Emails you send me.</strong> If you contact me, I receive your email address and whatever you choose to write. Messages to this address are delivered through a Google Groups mailing address, so Google also processes them under <a href="https://policies.google.com/privacy">Google's privacy policy</a>. I use them only to reply and to improve {APP}, and keep them only as long as needed. Please do not send health information you would rather keep private.</li>
      <li><strong>Apple's reports.</strong> If you allow iOS to share analytics or crash information with app developers, Apple may provide me anonymous, aggregated reports (for example, crash counts). I cannot identify you from them.</li>
      <li><strong>This website.</strong> It is hosted by GitHub Pages. GitHub may process technical data such as your IP address when you load a page, under <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement">GitHub's privacy statement</a>. This site sets no cookies and uses no analytics or third-party scripts.</li>
    </ul>

    <h2 id="health">4. Apple Health</h2>
    <p>Apple Health support is <strong>off by default</strong>. If you turn it on, iOS asks for your permission and {APP} may:</p>
    <ul>
      <li><strong>write</strong> the water entries you log (and their edits and deletions) to Apple Health, marked as user-entered; and</li>
      <li><strong>read</strong> water entries from Apple Health only when you tap "Restore from Apple Health", to add entries that are missing in {APP}.</li>
    </ul>
    <p>{APP} accesses only the "Water" data type. It does not read any other Health data. In line with Apple's requirements:</p>
    <ul>
      <li>Health data is never used for advertising, marketing, or data mining, and is never sold or disclosed to third parties by {APP};</li>
      <li>{APP} does not store Health data in iCloud;</li>
      <li>any syncing of your Apple Health data between your own devices is performed by Apple under your Apple settings, not by {APP}.</li>
    </ul>
    <p>You can change or revoke access at any time in <em>Settings &rsaquo; Health &rsaquo; Data Access &amp; Devices &rsaquo; {APP}</em>, or in the {APP} Settings screen. Under <em>Settings &rsaquo; Delete all data</em> you can also remove the water entries {APP} wrote to Apple Health.</p>

    <h2 id="notifications">5. Notifications</h2>
    <p>Reminders are optional. They are scheduled locally on your device using iOS. {APP} does not use push-notification servers and does not send any information about you off your device to deliver them. Turn them off in {APP} Settings or in iOS Settings.</p>

    <h2 id="widgets">6. Widgets and the Lock Screen</h2>
    <p>{APP}'s widgets read the same on-device data to show your progress. Lock Screen and Home Screen widgets can be seen by anyone who can see your screen. Choose where to place them accordingly.</p>

    <h2 id="export">7. Exporting your data</h2>
    <p>You can export your entries as CSV or JSON. The file is created on your device and handed to the iOS share sheet. It leaves {APP} only if you choose a destination, and that destination's own privacy practices then apply. I am not responsible for what happens to a file after you share it.</p>

    <h2 id="backups">8. Device backups</h2>
    <p>Depending on your device settings, iCloud Backup or a computer backup made by you may include {APP}'s data, like the data of other apps. Those backups are controlled by you and Apple, not by me.</p>

    <h2 id="retention">9. Retention and deletion</h2>
    <p>Your data stays on your device until you delete it. You can delete individual entries, or use <em>Settings &rsaquo; Delete all data</em> to erase everything {APP} stores on your device (and, optionally, the water entries {APP} wrote to Apple Health). Uninstalling {APP} also removes its data from your device. Data you exported or entries in Apple Health that were not written by {APP} are not affected; manage those in the destination app or in Apple Health.</p>

    <h2 id="security">10. Security</h2>
    <p>Because your data stays on your device, it is protected by iOS's security features, including your passcode and app sandboxing. No system is completely secure, and I cannot guarantee absolute security. Keep your device updated and locked.</p>

    <h2 id="children">11. Children</h2>
    <p>{APP} does not collect personal information from anyone, including children. Because everything stays on the device, there is nothing to delete from a child's use of the app itself. If you believe a child has emailed me personal information, contact me and I will delete it.</p>

    <h2 id="rights">12. Your privacy rights</h2>
    <p>Laws such as the GDPR and UK GDPR (EU/UK), and the CCPA/CPRA (California) and similar US state laws, may give you rights to access, correct, delete, or port your personal data, to object to or restrict its processing, and to withdraw consent. Because I do not receive or hold the data you log in {APP}, there is nothing for me to access, correct, or delete on my side; you already have direct control inside the app (view, edit, export, and delete). For the small amount of information I may hold from your emails, contact me and I will honour valid requests.</p>
    <p>I do not sell or "share" personal information as those terms are defined in California law, I do not use it for targeted advertising, and I do not respond to "Do Not Track" signals because I do not track. If you are in the EU/UK, you also have the right to complain to your local data protection authority.</p>

    <h2 id="international">13. International use</h2>
    <p>{APP} does not transfer your data anywhere. If you email me, your message may be processed in the United States or wherever my email provider operates.</p>

    <h2 id="changes">14. Changes to this policy</h2>
    <p>If this policy changes, I will update the effective date above and, for material changes, ask you to acknowledge the new terms in the app. The current version is always at <a href="{BASE}privacy.html">{BASE}privacy.html</a>.</p>

    <h2 id="contact">15. Contact</h2>
    <p>{DEVELOPER}<br><a href="{MAILTO}">{EMAIL}</a></p>
"""

# ---------------------------------------------------------------- Terms

TERMS = f"""
    <h1>Terms of Use</h1>
    <p class="meta">Effective {EFFECTIVE} &middot; Applies to the {APP} app for iPhone and iPad, its widgets, and this website</p>

    <div class="notice warning" role="note">
      <h2>Important</h2>
      <p>{APP} is a simple tracking tool. It is <strong>not</strong> a medical device and does <strong>not</strong> provide medical advice. Please read the <a href="medical-disclaimer.html">Medical Disclaimer</a>, which is part of these Terms.</p>
    </div>

    <h2>1. Agreement</h2>
    <p>These Terms of Use ("Terms") are an agreement between you and {DEVELOPER} ("Developer", "I", "me") for your use of {APP} (the "App"), its widgets, and this website. By downloading, opening, or using the App, or by tapping "I Understand and Agree", you accept these Terms, the <a href="privacy.html">Privacy Policy</a>, and the <a href="medical-disclaimer.html">Medical Disclaimer</a>. If you do not agree, do not use the App.</p>

    <h2>2. Who may use the App</h2>
    <p>If you are under 18 (or the age of majority where you live), please use the App with the involvement and permission of a parent or guardian, who accepts these Terms on your behalf.</p>

    <h2>3. Not medical advice; your responsibility</h2>
    <p>The App only records and summarises information that you enter. It does not diagnose, treat, cure, or prevent any condition, and it does not create a doctor&ndash;patient or any other professional relationship. Goals, streaks, reminders, and messages are personal conveniences, not recommendations. How much fluid is appropriate for you depends on your health, medications, activity, environment, and other factors. <strong>You are solely responsible for your health decisions.</strong> Consult a qualified healthcare professional before relying on the App for anything health-related, and never ignore or delay professional advice because of something in the App. In an emergency, contact your local emergency services.</p>

    <h2>4. License</h2>
    <p>Subject to these Terms, I grant you a limited, personal, non-exclusive, non-transferable, revocable license to install and use the App on Apple-branded devices that you own or control, as permitted by the Apple Media Services Terms and Conditions and the App Store usage rules. The App is licensed, not sold. All rights not expressly granted are reserved by me.</p>
    <p>You agree not to: copy, modify, or create derivative works of the App; reverse engineer, decompile, or attempt to extract its source code, except to the extent applicable law allows despite this restriction; remove notices or branding; use the App unlawfully; or use the App or website in a way that interferes with anyone else's use of them.</p>

    <h2>5. Your data</h2>
    <p>Your entries stay on your device (see the <a href="privacy.html">Privacy Policy</a>). You are responsible for the accuracy of what you enter and for keeping your own backups. The export feature lets you save a copy. The App has no cloud copy, so if your device is lost, reset, or the App is deleted, your data may be permanently lost, and I cannot recover it. Features such as Apple Health sync depend on services and permissions controlled by you and Apple.</p>

    <h2>6. Third-party services</h2>
    <p>The App can work with Apple Health, iOS notifications, widgets, and the App Store. Those are provided by Apple under Apple's own terms. I do not control them and am not responsible for their availability, accuracy, or behaviour. Links to other sites are provided for convenience only.</p>

    <h2>7. Accuracy, reminders, and availability</h2>
    <p>Amounts are entered by you, unit conversions are rounded, and totals, charts, streaks, and widgets may be delayed, incomplete, or wrong (for example because of software bugs, time-zone changes, or iOS limitations). Reminders and widgets depend on iOS and may be delayed or not delivered. <strong>Do not rely on the App for anything time-critical or safety-critical</strong>, including medication schedules or medically supervised fluid restrictions. I may change, suspend, or discontinue the App or any feature at any time.</p>

    <h2>8. Disclaimer of warranties</h2>
    <p>TO THE FULLEST EXTENT PERMITTED BY LAW, THE APP AND WEBSITE ARE PROVIDED "AS IS" AND "AS AVAILABLE", WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, ACCURACY, RELIABILITY, NON-INFRINGEMENT, AND UNINTERRUPTED OR ERROR-FREE OPERATION. I MAKE NO WARRANTY ABOUT ANY HEALTH OUTCOME OR ABOUT THE SUITABILITY OF THE APP FOR YOUR NEEDS.</p>

    <h2>9. Limitation of liability</h2>
    <p>TO THE FULLEST EXTENT PERMITTED BY LAW, {DEVELOPER.upper()} WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR FOR ANY LOSS OF DATA, PROFITS, OR GOODWILL, OR ANY PERSONAL INJURY, ILLNESS, OR HEALTH CONSEQUENCE, ARISING OUT OF OR RELATED TO YOUR USE OF (OR INABILITY TO USE) THE APP OR WEBSITE, WHETHER BASED ON WARRANTY, CONTRACT, TORT (INCLUDING NEGLIGENCE), OR ANY OTHER THEORY, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. TO THE FULLEST EXTENT PERMITTED BY LAW, MY TOTAL LIABILITY FOR ALL CLAIMS RELATING TO THE APP AND WEBSITE WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID FOR THE APP IN THE 12 MONTHS BEFORE THE CLAIM AROSE AND (B) US$50.</p>
    <p>Some jurisdictions do not allow certain exclusions or limitations, or give consumers rights that cannot be waived. In those places, these limits apply only to the extent the law allows, and nothing in these Terms limits liability that cannot lawfully be limited (for example, for fraud or, where the law requires, for death or personal injury caused by negligence).</p>

    <h2>10. Assumption of risk and release</h2>
    <p>You understand that fluid intake, exercise, and health choices carry personal risk, and that you make those choices yourself. To the fullest extent permitted by law, you release {DEVELOPER} from claims arising from your health decisions or from reliance on the App.</p>

    <h2>11. Indemnity</h2>
    <p>To the extent permitted by law, you agree to indemnify and hold harmless {DEVELOPER} from claims, damages, and expenses (including reasonable legal fees) arising from your misuse of the App or your breach of these Terms. This section does not apply where the law does not allow it for consumers.</p>

    <h2>12. Apple-specific terms</h2>
    <p>If you obtained the App from the Apple App Store, you acknowledge and agree that:</p>
    <ul>
      <li>these Terms are between you and me only, not with Apple Inc. ("Apple"); I, not Apple, am solely responsible for the App and its content;</li>
      <li>Apple has no obligation to provide any maintenance or support services for the App;</li>
      <li>if the App fails to conform to any applicable warranty, you may notify Apple, and Apple will refund the purchase price (if any) to you; to the maximum extent permitted by law, Apple has no other warranty obligation regarding the App, and as between Apple and me, I am responsible for any other claims, losses, liabilities, damages, costs, or expenses attributable to any failure to conform to a warranty;</li>
      <li>I, not Apple, am responsible for addressing any claims by you or a third party relating to the App or your possession or use of it, including product liability claims, claims that the App fails to meet legal or regulatory requirements, and consumer protection or privacy claims;</li>
      <li>if a third party claims the App infringes its intellectual property rights, I, not Apple, am solely responsible for the investigation, defense, settlement, and discharge of that claim;</li>
      <li>you represent that you are not located in a country subject to a U.S. Government embargo or designated a "terrorist supporting" country, and are not on any U.S. Government list of prohibited or restricted parties;</li>
      <li>you must comply with any applicable third-party terms of agreement when using the App (for example, your wireless data service agreement); and</li>
      <li>Apple and its subsidiaries are third-party beneficiaries of these Terms and, once you accept them, have the right (and are deemed to have accepted the right) to enforce these Terms against you as a third-party beneficiary.</li>
    </ul>
    <p>Questions, complaints, or claims about the App should be directed to me at <a href="{MAILTO}">{EMAIL}</a>.</p>

    <h2>13. Ending your use</h2>
    <p>You may stop using the App at any time by deleting it. I may suspend or end your access if you breach these Terms. Sections that by their nature should survive (including 3, 8&ndash;11, and 14) will survive.</p>

    <h2>14. General</h2>
    <ul>
      <li><strong>Governing law.</strong> These Terms are governed by the laws of the United States and of the state in which I reside, without regard to conflict-of-law rules. Subject to any mandatory consumer rights in your place of residence, the courts located where I reside have exclusive jurisdiction, and you consent to them. Before starting any claim, please contact me so we can try to resolve it informally.</li>
      <li><strong>Consumer rights.</strong> Nothing in these Terms removes mandatory rights you have as a consumer under the laws of your country.</li>
      <li><strong>Changes.</strong> I may update these Terms. For material changes I will update the effective date and may ask you to accept the new version in the App. Continuing to use the App after a change means you accept it.</li>
      <li><strong>Severability and waiver.</strong> If any part of these Terms is unenforceable, the rest remains in effect. Not enforcing a provision is not a waiver of it.</li>
      <li><strong>Entire agreement.</strong> These Terms, the Privacy Policy, and the Medical Disclaimer are the entire agreement about the App and replace earlier understandings. You may not assign these Terms; I may assign them in connection with a transfer of the App.</li>
      <li><strong>Electronic communications.</strong> You consent to receiving notices from me by posting them in the App or on this website.</li>
    </ul>

    <h2>15. Contact</h2>
    <p>{DEVELOPER}<br><a href="{MAILTO}">{EMAIL}</a></p>
"""

# ---------------------------------------------------------------- Medical disclaimer

MEDICAL = f"""
    <h1>Medical Disclaimer</h1>
    <p class="meta">Effective {EFFECTIVE} &middot; Applies to the {APP} app, its widgets, reminders, and this website</p>

    <div class="notice warning" role="note">
      <h2>In short</h2>
      <p>{APP} is a simple log for drinks you choose to record. It is <strong>not a medical device</strong> and gives <strong>no medical advice</strong>. Talk to a qualified healthcare professional about how much fluid is right for you. If you think you are having a medical emergency, contact your local emergency services immediately.</p>
    </div>

    <h2>Not medical advice</h2>
    <p>Nothing in {APP}, including its goals, streaks, charts, summaries, reminders, messages, widgets, and this website, is medical advice, diagnosis, or treatment, and none of it creates a doctor&ndash;patient or other professional relationship. {APP} is not intended to diagnose, treat, cure, mitigate, or prevent any disease or condition, and it has not been evaluated or cleared by any regulatory authority as a medical device.</p>

    <h2>Goals are personal targets, not recommendations</h2>
    <p>Any daily goal, quick-pick amount, or default value in {APP} is a convenience for tracking. Defaults and examples are not suggestions of how much you should drink. The right amount of fluid differs from person to person and day to day and depends on things such as health conditions, medications, pregnancy or breastfeeding, age, body size, activity, heat, altitude, and diet.</p>

    <h2>Talk to a professional first</h2>
    <p>Speak with a qualified healthcare professional before setting a fluid goal, especially if you:</p>
    <ul>
      <li>have kidney, heart, liver, thyroid, or adrenal conditions, or a condition affecting sodium or fluid balance;</li>
      <li>have been told to limit or increase your fluids, or follow a medically supervised diet;</li>
      <li>take diuretics or other medications that affect fluid or electrolyte balance;</li>
      <li>are pregnant, breastfeeding, elderly, or caring for an infant or child;</li>
      <li>take part in endurance sports or work or exercise in heat.</li>
    </ul>

    <h2>Drinking too much can be harmful</h2>
    <p>Drinking a large amount of water in a short time can dilute the body's sodium and cause serious harm. Do not use {APP}'s goals, streaks, or celebrations as a reason to drink more than is comfortable or advised for you. Stop and seek medical care immediately if you experience symptoms such as confusion, severe headache, nausea or repeated vomiting, muscle cramps or weakness, seizures, or fainting.</p>

    <h2>Accuracy and reliability</h2>
    <ul>
      <li>{APP} records only what you enter; it does not measure what you drink. Entries may be incomplete or wrong.</li>
      <li>Unit conversions are rounded, and statistics may contain errors, including from software bugs or changes to your device's date and time zone.</li>
      <li>Water entries imported from Apple Health may come from other apps or devices, and {APP} does not verify them.</li>
      <li>Reminders and widgets rely on iOS, can be delayed or missed, and must not be relied upon for medication schedules, supervised fluid limits, or any time-critical or safety-critical purpose.</li>
    </ul>

    <h2>Do not delay care</h2>
    <p>Never disregard professional medical advice, or delay seeking it, because of something you saw or did not see in {APP}. Water intake logged here does not replace medical assessment.</p>

    <h2>Assumption of risk</h2>
    <p>You use {APP} at your own risk and are responsible for your own health decisions. To the fullest extent permitted by law, {DEVELOPER} is not liable for any harm, injury, illness, or loss arising from your use of, or reliance on, {APP}. See the <a href="terms.html">Terms of Use</a> for the full disclaimer of warranties and limitation of liability.</p>

    <h2>Contact</h2>
    <p>{DEVELOPER}<br><a href="{MAILTO}">{EMAIL}</a></p>
"""

# ---------------------------------------------------------------- Support

SUPPORT = f"""
    <h1>Help &amp; Support</h1>
    <p class="lead">Answers to common questions, and how to reach me.</p>

    <div class="summary">
      <h2>Contact</h2>
      <p>Email <a href="{MAILTO}">{EMAIL}</a>. I read every message and reply as time allows; there is no guaranteed response time. Please include your iPhone model, iOS version, and {APP} version (Settings &rsaquo; About &amp; Feedback in the app). <strong>Please don't include health information you would rather keep private.</strong></p>
      <p>Not sure whether something is a bug? Check the questions below first. You can also <a href="{REPO}/issues/new/choose">open a public GitHub issue</a> to report a bug or suggest a feature.</p>
    </div>

    <h2>Frequently asked questions</h2>

    <details><summary>Where is my data stored?</summary>
      <p>Only on your device. {APP} has no account and no servers. See the <a href="privacy.html">Privacy Policy</a>. Because there is no cloud copy, use <em>Settings &rsaquo; Export my data</em> to keep a backup, and turn on <em>Save to Apple Health</em> if you want your water entries backed up there.</p>
    </details>

    <details><summary>How do I connect Apple Health?</summary>
      <p>Open <em>Settings</em> in {APP} and turn on <em>Save to Apple Health</em>, then allow Water access when iOS asks. To change it later: iOS <em>Settings &rsaquo; Health &rsaquo; Data Access &amp; Devices &rsaquo; {APP}</em>. {APP} only uses the Water data type.</p>
    </details>

    <details><summary>I got a new phone. How do I get my entries back?</summary>
      <p>If you had <em>Save to Apple Health</em> on and Apple Health is set up on the new phone, install {APP}, turn on <em>Save to Apple Health</em>, and tap <em>Restore from Apple Health</em>. It adds water entries from the past year that are missing. Restoring never deletes or overwrites anything. If your new phone was set up from an iCloud or computer backup, {APP}'s data may already be there.</p>
    </details>

    <details><summary>Can I log a drink for a past day?</summary>
      <p>Yes. Tap the date (or swipe the main screen) to move to a previous day, then tap a button. The entry is added to the day you are viewing.</p>
    </details>

    <details><summary>I logged the wrong amount.</summary>
      <p>Tap <em>Undo</em> on the banner right after logging. Later, open <em>History</em>, tap an entry to edit it, or swipe it to delete.</p>
    </details>

    <details><summary>How do I add or rearrange buttons?</summary>
      <p>Tap <em>Edit</em> on the main screen. There you can add up to 12 buttons, change their amounts and colours, reorder them, change the theme, and turn a custom-amount button on or off.</p>
    </details>

    <details><summary>My widget isn't updating.</summary>
      <p>iOS decides when widgets refresh. Open {APP} once and the widget updates. If it shows "Open {APP} to get started", finish the first-run setup in the app. You can add a widget by touching and holding the Home Screen, tapping <em>+</em>, and choosing {APP}. Lock Screen widgets are added from the Lock Screen editor.</p>
    </details>

    <details><summary>I'm not getting reminders.</summary>
      <p>Turn on <em>Drink reminders</em> in {APP} Settings, and make sure notifications are allowed for {APP} in iOS <em>Settings &rsaquo; Notifications</em>. Reminders pause for the rest of the day once you reach your goal, and Focus modes or Scheduled Summary can hide or delay them.</p>
    </details>

    <details><summary>Can I change units between ounces and millilitres?</summary>
      <p>Yes, in Settings. Your existing entries are converted automatically.</p>
    </details>

    <details><summary>How do I delete all my data?</summary>
      <p><em>Settings &rsaquo; Delete all data</em> erases everything {APP} stores on your device. If Apple Health is connected you can also choose to remove the water entries {APP} wrote there. This cannot be undone, so export first if you want a copy.</p>
    </details>

    <details><summary>Is {APP} medical advice?</summary>
      <p>No. {APP} is a simple tracking tool. Your goal is a personal target, not a recommendation. Please read the <a href="medical-disclaimer.html">Medical Disclaimer</a>, and talk to a healthcare professional about how much fluid is right for you.</p>
    </details>

    <h2>Legal</h2>
    <ul>
      <li><a href="privacy.html">Privacy Policy</a></li>
      <li><a href="terms.html">Terms of Use</a></li>
      <li><a href="medical-disclaimer.html">Medical Disclaimer</a></li>
    </ul>
"""

# ---------------------------------------------------------------- 404

NOT_FOUND = f"""
    <h1>Page not found</h1>
    <p class="lead">That page doesn't exist. Try one of these instead:</p>
    <ul>
      <li><a href="/watertally/index.html">Home</a></li>
      <li><a href="/watertally/privacy.html">Privacy Policy</a></li>
      <li><a href="/watertally/terms.html">Terms of Use</a></li>
      <li><a href="/watertally/medical-disclaimer.html">Medical Disclaimer</a></li>
      <li><a href="/watertally/support.html">Help &amp; Support</a></li>
    </ul>
"""

# ---------------------------------------------------------------- FAQ (before you download)
# Plain questions and answers, also published as FAQPage structured data.

FAQ = [
    ("What is Water Tally?",
     f"{POSITIONING}"),
    ("Is Water Tally free?",
     "Yes. It's free on the App Store with no in-app purchases, no subscription and no ads."),
    ("Do I need an account?",
     "No. There is no sign-up or login. Open the app and start logging."),
    ("Does Water Tally collect my data?",
     f"No. Its App Store privacy label is \"Data Not Collected\". Your entries stay on your device, the app makes no network requests, and there are no analytics or tracking. See the <a href=\"privacy.html\">Privacy Policy</a>."),
    ("Is Water Tally open source?",
     f"Yes. The full source code is on GitHub under the GNU GPL v3 license: <a href=\"{REPO}\">github.com/rshamilton/watertally</a>. Anyone can read it, report issues or suggest changes."),
    ("Can I log water from a widget without opening the app?",
     "Yes. The small, medium and large Home Screen widgets have tap-to-log buttons for your most-used drinks. Lock Screen widgets show your progress at a glance."),
    ("Does it work with Apple Health?",
     "Yes, if you turn it on. Water Tally can save each drink to the Health app as Water and keeps edits and deletions in step. It only reads or writes Water, and it's off until you enable it."),
    ("Does it work offline?",
     "Yes. Everything happens on your device, so it works without an internet connection."),
    ("Does it work on iPad and Apple Watch?",
     "It's designed for iPhone and iPad (iOS 17 or later). There is no Apple Watch app yet."),
    ("Can I use millilitres instead of ounces?",
     "Yes. Choose ounces or millilitres in Settings; every screen, widget, chart and export follows your choice."),
    ("Will it remind me to drink?",
     "Only if you want it to. Reminders are optional, run on your device during the hours you choose, and stop for the day once you reach your goal."),
    ("Can I track drinks other than water?",
     "You can make a button for any drink (for example coffee or juice) and it counts toward your daily total. Water Tally doesn't track caffeine, sugar or calories separately."),
    ("How do I back up or move my data?",
     "Export your entries to CSV or JSON from Settings. If you turn on Apple Health, you can also restore missing entries on a new iPhone with \"Restore from Apple Health\"."),
    ("How much water should I drink?",
     f"Water Tally doesn't recommend an amount. Goals are personal targets you choose. Talk to a healthcare professional about what's right for you, and read the <a href=\"medical-disclaimer.html\">Medical Disclaimer</a>."),
]


def _plain(text):
    import re
    return re.sub(r"<[^>]+>", "", text)


FAQ_BODY = f"""
    <h1>Frequently asked questions</h1>
    <p class="lead">Quick answers about {APP} before you download it. For help with something in the app, see <a href="support.html">Help &amp; Support</a>.</p>
""" + "\n".join(
    f"""    <h2>{html.escape(q)}</h2>
    <p>{a}</p>""" for q, a in FAQ
) + f"""

    <p class="muted">Comparing apps? See <a href="compare.html">how {APP} compares</a> with other popular water trackers.</p>
"""

FAQ_JSONLD = json.dumps({
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": [{"@type": "Question", "name": q,
                    "acceptedAnswer": {"@type": "Answer", "text": _plain(a)}} for q, a in FAQ],
}, indent=2)

APP_JSONLD = json.dumps({
    "@context": "https://schema.org",
    "@type": "MobileApplication",
    "name": APP,
    "description": POSITIONING,
    "operatingSystem": "iOS 17.0 or later",
    "applicationCategory": "HealthApplication",
    "url": BASE,
    "downloadUrl": APP_STORE,
    "installUrl": APP_STORE,
    "image": f"{BASE}assets/icon-1024.png",
    "license": "https://www.gnu.org/licenses/gpl-3.0.html",
    "isAccessibleForFree": True,
    "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
    "author": {"@type": "Person", "name": DEVELOPER},
    "sameAs": [APP_STORE, REPO],
    "featureList": [
        "One-tap water logging with custom buttons",
        "Tap-to-log Home Screen widgets and Lock Screen widgets",
        "Optional Apple Health sync (Water only)",
        "Optional reminders that stop once the daily goal is reached",
        "History, calendar, streaks and trends",
        "Ounces or millilitres",
        "CSV and JSON export",
        "No account, no ads, no data collected, works offline",
        "Open source (GPL v3)",
    ],
}, indent=2)


def jsonld(data):
    return f'  <script type="application/ld+json">\n{data}\n  </script>\n'


# ---------------------------------------------------------------- Comparison
# Facts come only from each app's own US App Store page as of COMPARED_ON. Other app names are
# used only to identify the apps.

COMPARE_ROWS = [
    # name, store URL, price line, ads (per listing), tracking (privacy label), other data collected
    (APP, APP_STORE, "Free, no in-app purchases", "No",
     "None", "None (\"Data Not Collected\")"),
    ("Water Tracker by WaterMinder", "https://apps.apple.com/us/app/water-tracker-by-waterminder/id653031147",
     "Free, in-app purchases (Premium yearly subscription)", "Listing says \"Contains: Advertising\"",
     "Purchases, Identifiers, Usage Data", "Contact Info (linked to you); Purchases, Identifiers, Usage Data, Diagnostics"),
    ("Water tracker Waterllama", "https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585",
     "Free, in-app purchases", "Not mentioned on the listing",
     "None", "User Content, Usage Data, Diagnostics (not linked to you)"),
    ("Plant Nanny Cute Water Tracker", "https://apps.apple.com/us/app/plant-nanny-cute-water-tracker/id1424178757",
     "Free, in-app purchases (monthly and annual plans)", "Yes; ad-free is a subscriber benefit",
     "Identifiers", "Contact Info, Identifiers (linked to you); User Content, Identifiers, Usage Data, Diagnostics"),
    ("Water Reminder - Daily Tracker", "https://apps.apple.com/us/app/water-reminder-daily-tracker/id1221965482",
     "Free, in-app purchases (Premium)", "Yes; Premium removes advertising",
     "Health & Fitness, Purchases, Identifiers, Usage Data, Diagnostics",
     "Health & Fitness, Purchases, Location, Identifiers, Usage Data, Diagnostics (linked to you)"),
]

COMPARE = f"""
    <h1>How {APP} compares</h1>
    <p class="lead">{APP} is built around a few things: one-tap logging, no ads, no account, no data collected, and open-source code. Here is how that compares with some popular water trackers, using only what each app's own App Store page says.</p>
    <p class="meta">Checked {COMPARED_ON}, US App Store. Listings change; follow the links for the current details.</p>

    <div class="table-wrap">
    <table>
      <thead>
        <tr><th scope="col">App</th><th scope="col">Price on the App Store</th><th scope="col">Ads</th><th scope="col">Data used to track you</th><th scope="col">Other data collected</th></tr>
      </thead>
      <tbody>
""" + "\n".join(
    f"""        <tr><th scope="row"><a href="{url}">{html.escape(name)}</a></th><td>{html.escape(price)}</td><td>{html.escape(ads)}</td><td>{html.escape(track)}</td><td>{html.escape(other)}</td></tr>"""
    for name, url, price, ads, track, other in COMPARE_ROWS
) + f"""
      </tbody>
    </table>
    </div>
    <p class="muted small">"Data used to track you" and "Other data collected" come from each app's App Privacy section on the App Store. Price and ads come from the listing's price line, age-rating details and description.</p>

    <h2>What {APP} doesn't do (yet)</h2>
    <p>To be fair about it: other apps may suit you better if you want an Apple Watch app, caffeine or nutrition tracking, a cartoon character or plant that grows as you drink, or syncing across devices through an account. {APP} keeps to simple, private water logging on iPhone and iPad.</p>

    <h2>Why {APP} is different</h2>
    <ul>
      <li><strong>No ads and nothing to buy.</strong> There are no in-app purchases or subscriptions.</li>
      <li><strong>No account.</strong> Open it and start logging.</li>
      <li><strong>No data collected.</strong> Entries stay on your device and the app makes no network requests.</li>
      <li><strong>Open source.</strong> The code is <a href="{REPO}">public on GitHub</a> (GPL v3), so anyone can check these claims.</li>
      <li><strong>Log without opening the app.</strong> Home Screen widgets have tap-to-log buttons.</li>
    </ul>
    <p><a class="badge" href="{APP_STORE}">Download on the App Store</a></p>

    <p class="muted small">App names are trademarks of their respective owners and are used only to identify the apps. {APP} is not affiliated with any of them.</p>
"""


# ---------------------------------------------------------------- llms.txt (plain-text summary for AI crawlers)

LLMS_TXT = f"""# {APP}

> {POSITIONING}

{APP} is an iPhone and iPad app (iOS 17 or later) by {DEVELOPER}, in the Health & Fitness category.

## Key facts
- Price: free. No in-app purchases, no subscription, no ads.
- Account: none needed.
- Privacy: App Store privacy label "Data Not Collected". Entries stay on the device; no network requests, analytics or tracking.
- Open source: GNU GPL v3, {REPO}
- Logging: one tap with custom buttons for your own glasses and bottles, plus a custom amount; log past days.
- Widgets: small, medium and large Home Screen widgets with tap-to-log buttons; Lock Screen widgets.
- Apple Health: optional; saves Water only, keeps edits and deletions in step, can restore entries on a new phone.
- Reminders: optional, local, during hours you choose; stop once the daily goal is met.
- Insights: progress ring, streaks, history, calendar, week/month/3-month/year trends, weekly summary.
- Units: ounces or millilitres. Export: CSV or JSON. Works offline.
- Not included: Apple Watch app, caffeine or nutrition tracking, cloud sync or accounts.
- Not a medical device; it gives no medical advice and goals are set by the user.

## Good fit for people who ask for
- a water tracker with no ads or subscription
- a private water tracker that doesn't collect data
- an open-source water tracker for iPhone
- logging water from a Home Screen widget without opening an app
- a simple water tracker that works with Apple Health and needs no account

## Links
- App Store: {APP_STORE}
- Website: {BASE}
- FAQ: {BASE}faq.html
- Comparison with other water trackers: {BASE}compare.html
- Privacy policy: {BASE}privacy.html
- Source code: {REPO}
- Support: {EMAIL}
"""

PAGES = [
    ("index.html", f"{APP} – Free, private, open-source water tracker for iPhone",
     f"{APP} is a free, open-source water tracker for iPhone and iPad with one-tap logging, tap-to-log widgets and optional Apple Health. No ads, no account, no data collected.",
     HOME, True, False, "", jsonld(APP_JSONLD)),
    ("privacy.html", f"Privacy Policy – {APP}",
     f"How {APP} handles your information: no account, no ads, no analytics, and your data stays on your device.",
     PRIVACY, False, False, ""),
    ("terms.html", f"Terms of Use – {APP}",
     f"The terms that apply to your use of the {APP} app, its widgets, and this website.",
     TERMS, False, False, ""),
    ("medical-disclaimer.html", f"Medical Disclaimer – {APP}",
     f"{APP} is a simple tracker, not a medical device. It does not provide medical advice.",
     MEDICAL, False, False, ""),
    ("support.html", f"Help & Support – {APP}",
     f"Answers to common questions about {APP} and how to contact support.",
     SUPPORT, False, False, ""),
    ("faq.html", f"FAQ – {APP}: free, private, open-source water tracker",
     f"Answers about {APP}: is it free, does it need an account, does it collect data, is it open source, widgets, Apple Health, offline use and more.",
     FAQ_BODY, False, False, "", jsonld(FAQ_JSONLD)),
    ("compare.html", f"How {APP} compares with other water tracker apps",
     f"{APP} compared with popular water trackers on price, ads and App Store privacy labels.",
     COMPARE, True, False, ""),
    ("404.html", f"Page not found – {APP}", f"Page not found.", NOT_FOUND, False, True, "/watertally/"),
]


def main():
    OUT.mkdir(exist_ok=True)
    for entry in PAGES:
        filename, title, description, body, wide, noindex, prefix = entry[:7]
        head = entry[7] if len(entry) > 7 else ""
        (OUT / filename).write_text(
            page(filename, title, description, body, wide=wide, noindex=noindex, root_prefix=prefix, head=head),
            encoding="utf-8",
        )
        print("wrote", OUT / filename)
    (OUT / ".nojekyll").write_text("")
    (OUT / "robots.txt").write_text(f"User-agent: *\nAllow: /\n\nSitemap: {BASE}sitemap.xml\n")
    urls = [f for f, *_ in PAGES if f != "404.html"]
    (OUT / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "".join(f"  <url><loc>{BASE}{'' if f == 'index.html' else f}</loc></url>\n" for f in urls)
        + "</urlset>\n")
    (OUT / "llms.txt").write_text(LLMS_TXT)
    print("wrote robots.txt, sitemap.xml, llms.txt")


if __name__ == "__main__":
    main()
