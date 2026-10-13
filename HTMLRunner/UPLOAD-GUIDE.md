# How to upload HTML Runner to GitHub

Uploading is what puts your project where GitHub's free macOS build machine can
reach it. Pick **one** of the three methods below — they all end at the same place.

| Method | Good if you… | Command line? | Handles the hidden `.github` folder? |
|---|---|---|---|
| **A — GitHub Desktop** | want the fewest clicks | No | ✅ automatically |
| **B — Browser upload** | don't want to install anything | No | ⚠️ needs one extra step (included) |
| **C — git** | already know git | Yes | ✅ automatically |

At the end, your repository should look exactly like this:

```
your-repo/                     ← the repo root
├── .github/
│   └── workflows/
│       └── build-ipa.yml      ← ⚠️ must be at this exact path
├── HTMLRunner.xcodeproj/
├── HTMLRunner/
├── ShareExtension/
├── Shared/
├── tools/
└── README.md
```

If `.github/workflows/build-ipa.yml` is not at the **root** of the repo, the
**Actions** tab will show nothing and nothing will build. That is the single most
common upload mistake.

---

## Method A — GitHub Desktop (recommended, no command line)

1. **Unzip** `HTMLRunner-iOS.zip`. You get a folder called `HTMLRunner`. Inside it
   you should see `HTMLRunner.xcodeproj`, `ShareExtension`, `tools`, `README.md`
   (and a hidden `.github`).

2. Download **GitHub Desktop** from **desktop.github.com**, install it, open it and
   **sign in** with your GitHub account.

3. Menu: **File → Add Local Repository…** → **Choose…** → select the unzipped
   `HTMLRunner` folder → *Add Repository*.

4. GitHub Desktop will say it isn't a Git repository yet and offer a link —
   click **create a repository** (or "Create repository here").
   * Name: `html-runner`  (or anything you like)
   * Git ignore / License: **None**
   * Click **Create repository**
   *(Don't add a README — you already have one.)*

5. In the bottom-left box type a summary, e.g. `initial commit`, then click
   **Commit to main**.

6. Click **Publish repository** in the top bar. Untick **Keep this code private**
   if you want a public repo (unlimited free build minutes), or leave it ticked
   for private (2,000 minutes/month, macOS minutes count 10×).
   Click **Publish repository**.

7. Done — everything, including `.github/workflows/build-ipa.yml`, is on GitHub.

➡️ **Next:** open the repo on github.com → **Actions** tab → **Build IPA** →
**Run workflow**. (Full details in the README, *Getting an .ipa — Route 1*.)

---

## Method B — Browser upload (nothing to install)

### B1 — upload the visible files

1. Create the repo: **github.com → + → New repository**. Name `html-runner`,
   choose Public or Private, click **Create repository**. Do **not** add a README.

2. Unzip `HTMLRunner-iOS.zip` and open the `HTMLRunner` folder.

3. On the empty repo page click the **uploading an existing file** link.

4. Drag these items from inside the unzipped folder into the dotted upload box:
   `HTMLRunner.xcodeproj`, `HTMLRunner`, `ShareExtension`, `Shared`, `tools`,
   `README.md`.
   *(Drag the items **inside** the folder, not the folder itself — otherwise
   everything ends up one level too deep.)*

5. Type a commit message like `initial upload` → click **Commit changes**.

### B2 — create the workflow file (the extra step)

The `.github` folder starts with a dot, so Finder/Explorer hides it and the drag
above skipped it. GitHub Actions needs that exact path, so create it by hand —
it takes 30 seconds:

6. In your repo: **Add file → Create new file**.

7. In the filename field type precisely (typing the slashes creates the folders):

   ```
   .github/workflows/build-ipa.yml
   ```

8. Open `tools/build-ipa.copy.yml` from your unzipped folder in Notepad /
   TextEdit, select **all** of it (Ctrl/Cmd + A), and paste it into the big text
   box on GitHub. (That file is an identical copy of the real workflow, plus a
   header explaining this exact step.)

9. Click **Commit changes**.

10. Click the **Actions** tab — you should now see **Build IPA** in the left
    sidebar. 🎉

---

## Method C — git command line

```bash
cd HTMLRunner                 # the unzipped folder (the one containing .github)
git init
git add -A
git commit -m "initial commit"
git branch -M main
git remote add origin https://github.com/<your-username>/html-runner.git
git push -u origin main
```

Create an empty repo on GitHub first (no README, no .gitignore). If it complains
about authentication, use a Personal Access Token as the password
(Settings → Developer settings → Personal access tokens → Fine-grained token,
scope `contents: read/write`) — or install the GitHub CLI (`gh auth login`) and
run `gh repo create html-runner --private --source . --push`.

To update later: change the file, then

```bash
git add -A && git commit -m "update" && git push
```

The workflow re-runs automatically on every push.

---

## Then: run the build

Whatever method you used:

1. Repo → **Actions** → **Build IPA** → **Run workflow** → **Run workflow**
2. Wait 3–6 minutes. Jobs: `locate`, `unsigned-ipa` (this one matters),
   `signed-ipa` (grey/"skipped" — correct, it needs paid-account secrets).
3. Green tick → open the run → scroll down → **Artifacts** → download
   **HTMLRunner-unsigned-ipa** → unzip → `HTMLRunner-unsigned.ipa`.
4. Install it with Sideloadly (see README → Route 1, steps 4–6).

---

## If you meant “upload the .ipa to my iPhone”

That part is Sideloadly, not GitHub:

1. Install **Sideloadly** from sideloadly.io on your PC/Mac (on Windows let it
   install the Apple drivers when asked).
2. Plug in the iPhone, unlock it, tap **Trust**.
3. Open `HTMLRunner-unsigned.ipa` in Sideloadly, select the device, enter your
   **Apple ID**, click **Start**.
4. On the iPhone: **Settings → General → VPN & Device Management → your Apple ID
   → Trust**.
5. iOS 16+: **Settings → Privacy & Security → Developer Mode → on**, then restart
   the phone. (This toggle sometimes only appears after you try to open the app
   once and tap the alert away.)
6. Enable it in the share sheet: Share → **More/Edit** → toggle **HTML Runner** on.

Free Apple IDs expire after 7 days — repeat step 3 to renew (nothing in your
library is lost).

---

## Common problems

| What you see | Why | Fix |
|---|---|---|
| **Actions** tab empty / no “Build IPA” | `.github/workflows/build-ipa.yml` isn't at the **repo root** — often because the local repo was created one folder too high, so everything sits inside a single `HTMLRunner/` folder | On github.com the repo root must show `.github`, `HTMLRunner.xcodeproj`, `HTMLRunner`, `ShareExtension`, `Shared`, `tools`, `README.md`. If you only see one folder, fix it: GitHub Desktop → File → Add Local Repository → pick the folder that *directly* contains `HTMLRunner.xcodeproj` and `.github` → publish that repo |
| GitHub Desktop: commit button does nothing, tooltip *“Please fill out this field”* | The **Summary (required)** box above it is empty | Type anything, e.g. `Initial commit`, then click **Commit to main** |
| GitHub Desktop: no **Publish repository** button | The folder was added without creating a repository there | File → Add Local Repository → use the “create a repository” link; the Publish button appears in the top bar once a local repo exists |
| Repo shows `HTMLRunner/HTMLRunner.xcodeproj` (double nested) | The whole folder was dragged in, not its contents | That's fine for the build (the workflow searches 3 levels deep), but the workflow file must still be at root |
| Workflow fails at **Locate project** / *“HTMLRunner.xcodeproj not found”* | The repo has no `.xcodeproj` — the web uploader skipped the folders (it only uploads folders in Chrome/Edge, and silently drops them in Firefox/Safari) | Check the repo home page: you should see folders `HTMLRunner.xcodeproj`, `HTMLRunner`, `ShareExtension`, `Shared`, `tools`. If they are missing, re-upload with **GitHub Desktop** (Method A). If you uploaded `HTMLRunner-iOS.zip` instead, the updated workflow now unpacks it automatically — just re-run. |
| Workflow runs, fails at “Build” | Xcode/runner hiccup or a code error | Open the failed job, copy the last ~30 lines, send them to me |
| Workflow won't start at all | Actions disabled, or the repo is a fork | Settings → Actions → allow actions; or use your own repo |
| VS Code: *“This file uses 'LF' line endings, but Git is configured to convert them to 'CRLF'”* | Windows Git (`core.autocrlf=true`) warning about future checkouts, not an error | Ignore it, or add the included `.gitattributes` file (pins LF) — see the note at the bottom of this guide |
| Artifacts section missing | You're not signed in to GitHub, or the run is older than 30 days | Sign in; re-run the workflow |

---

## Note: the “LF / CRLF” message in VS Code

Nothing is broken. Line endings are just the invisible characters that end each
line: **LF** (`\n`, Unix/macOS) or **CRLF** (`\r\n`, Windows). Your file uses
LF; your Windows Git is set to *convert* LF to CRLF on future checkouts, so
VS Code is telling you it may change the file's endings later.

Why it doesn't matter for building the app: Xcode, Swift, YAML and plists all
read either ending happily. The one place CRLF genuinely breaks something is
`tools/make_ipa.sh`, a bash script used only on macOS — CRLF makes it fail with
`bad interpreter`. The included `.gitattributes` pins every text file to LF so it
can never happen.

**Options, easiest first:**

1. **Do nothing.** The message is informational. The GitHub build works either way.
2. **Commit the `.gitattributes`** that ships with this project (already in the
   zip). Upload it the same way you uploaded the other files. It pins LF
   repo-wide and the warning stops appearing.
3. **Turn the conversion off globally** (Windows):
   ```bash
   git config --global core.autocrlf false
   ```
   then in VS Code click the **LF/CRLF** indicator in the bottom-right
   status bar and choose **LF**.
4. **Already committed the files with CRLF?** Normalise them once:
   ```bash
   git add --renormalize .
   git commit -m "normalise line endings"
   git push
   ```
