/**
 * [Chatbox CE] No-op Windows code-signing hook.
 *
 * Upstream references ./custom_win_sign.js from electron-builder.yml but the
 * file is not part of the repository, which makes `electron-builder --win` fail
 * with "Cannot find module". Community Edition builds are not signed (no
 * certificate, no official release identity), so the hook intentionally does
 * nothing.
 *
 * If you own a code-signing certificate, replace this file with your own
 * implementation (or delete it and drop `signtoolOptions.sign` from
 * electron-builder.yml).
 */
exports.default = async function signWindows(context) {
  const { electronPlatformName } = context
  if (electronPlatformName !== 'win32') {
    return
  }
  console.warn('[Chatbox CE] Skipping Windows code signing: community builds are unsigned.')
}
