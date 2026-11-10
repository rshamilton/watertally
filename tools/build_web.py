#!/usr/bin/env python3
"""
Builds the static website in web/ (for GitHub Pages at https://rshamilton.github.io/watertally/).

Every page shares one header/footer, so the pages are generated from this file.
Run from the repo root:   python3 tools/build_web.py
Edit the constants below (name, email, dates) and re-run to update every page at once.
"""
import html
import pathlib
import urllib.parse

APP = "Water Tally"
DEVELOPER = "Ryan Hamilton"
EMAIL = "watertally@googlegroups.com"
BASE = "https://rshamilton.github.io/watertally/"
EFFECTIVE = "September 21, 2026"
YEAR = "2026"
BUNDLE = "me.ryham.WaterTally"

OUT = pathlib.Path(__file__).resolve().parent.parent / "web"

NAV = [
    ("index.html", "Home"),
    ("privacy.html", "Privacy"),
    ("terms.html", "Terms"),
    ("medical-disclaimer.html", "Medical Disclaimer"),
    ("support.html", "Support"),
]

MAILTO = f"mailto:{EMAIL}?subject={urllib.parse.quote(APP + ' Support')}"


def page(filename, title, description, body, wide=False, noindex=False, root_prefix=""):
    nav = "\n".join(
        f'        <li><a href="{root_prefix}{href}"{" aria-current=\"page\"" if href == filename else ""}>{label}</a></li>'
        for href, label in NAV
    )
    footer_links = "\n".join(f'        <li><a href="{root_prefix}{href}">{label}</a></li>' for href, label in NAV)
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
  <meta name="theme-color" content="#04101c">
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
      <p class="lead">Simple, private water tracking for iPhone. Log a drink in one tap, see your day at a glance, and keep your data on your device.</p>
      <span class="badge">Coming soon to the App Store</span>
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

    <p class="muted">Questions? See <a href="support.html">Help &amp; Support</a> or read the <a href="privacy.html">Privacy Policy</a> and <a href="terms.html">Terms of Use</a>.</p>
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
    <p>{APP} is not directed to children under 13 (or under the minimum age of digital consent where you live), and I do not knowingly collect information from children. Because {APP} does not collect information from anyone, there is nothing to delete from a child's use of the app itself. If you believe a child has emailed me personal information, contact me and I will delete it.</p>

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
    <p>You must be at least 13 years old (or the minimum age of digital consent where you live, if higher). If you are under 18 (or the age of majority where you live), you may use the App only with the involvement and permission of a parent or guardian, who accepts these Terms on your behalf.</p>

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
      <p>Email <a href="{MAILTO}">{EMAIL}</a>. I read every message and reply as time allows; there is no guaranteed response time. Please include your iPhone model, iOS version, and {APP} version (Settings &rsaquo; About in the app). <strong>Please don't include health information you would rather keep private.</strong></p>
      <p>Not sure whether something is a bug? Check the questions below first.</p>
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

PAGES = [
    ("index.html", f"{APP} – Simple, private water tracking for iPhone",
     f"{APP} is a simple, private water tracker for iPhone with one-tap logging, widgets, and optional Apple Health. No account, no ads, no tracking.",
     HOME, True, False, ""),
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
    ("404.html", f"Page not found – {APP}", f"Page not found.", NOT_FOUND, False, True, "/watertally/"),
]


def main():
    OUT.mkdir(exist_ok=True)
    for filename, title, description, body, wide, noindex, prefix in PAGES:
        (OUT / filename).write_text(
            page(filename, title, description, body, wide=wide, noindex=noindex, root_prefix=prefix),
            encoding="utf-8",
        )
        print("wrote", OUT / filename)
    (OUT / ".nojekyll").write_text("")
    (OUT / "robots.txt").write_text(f"User-agent: *\nAllow: /\n")


if __name__ == "__main__":
    main()
