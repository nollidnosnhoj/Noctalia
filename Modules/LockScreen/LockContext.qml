import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.Commons

Scope {
  id: root
  signal unlocked
  signal failed

  property string currentText: ""
  property bool unlockInProgress: false
  property bool showFailure: false
  property string errorMessage: ""
  property bool pamAvailable: typeof PamContext !== "undefined"
  property bool passwordEntered: false

  onCurrentTextChanged: {
    if (currentText !== "") {
      showFailure = false
      errorMessage = ""
    }
  }

  function startPAM() {
    if (!pamAvailable) {
      errorMessage = "PAM not available"
      showFailure = true
      return
    }

    root.unlockInProgress = true
    errorMessage = ""
    showFailure = false

    Logger.log("LockContext", "Initial start of PAM authentication for user:", pam.user)
    Logger.log("LockContext", "passwordEntered0", passwordEntered)
    pam.start()
  }

  function tryUnlock() {
    if (!pamAvailable) {
      errorMessage = "PAM not available"
      showFailure = true
      return
    }

    if (currentText === "") {
      errorMessage = "Password required"
      showFailure = true
      return
    }

    // this will ensure the PAMContext that we are using password method
    passwordEntered = true

    root.unlockInProgress = true
    errorMessage = ""
    showFailure = false

    Logger.log("LockContext", "Starting PAM authentication for user:", pam.user)
    pam.start()
  }

  PamContext {
    id: pam
    config: "login"
    user: Quickshell.env("USER")

    onPamMessage: {
      Logger.log("LockContext", "PAM message:", message, "isError:", messageIsError, "responseRequired:", responseRequired)

      if (messageIsError) {
        errorMessage = message
      }

      if (responseRequired) {
        Logger.log("LockContext", "passwordEntered1", passwordEntered)
        Logger.log("LockContext", "Responding to PAM with password")
        respond(root.currentText)
      }
    }

    onResponseRequiredChanged: {
      Logger.log("LockContext", "passwordEntered2", passwordEntered)
      Logger.log("LockContext", "Response required changed:", responseRequired)
      if (responseRequired && root.unlockInProgress && passwordEntered) {
        Logger.log("LockContext", "Automatically responding to PAM")
        respond(root.currentText)
      // If passwordEntered is false, we can assume the current PAM method is not password.
      } else if (!passwordEntered) {
        Logger.log("LockContext", "No password entered. Aborting PAM context...")
        root.unlockInProgress = false;
        pam.abort();
      }
    }

    onCompleted: result => {
      Logger.log("LockContext", "PAM completed with result:", result)
      if (result === PamResult.Success) {
        Logger.log("LockContext", "Authentication successful")
        root.unlocked()
      } else {
        Logger.log("LockContext", "Authentication failed")
        errorMessage = "Authentication failed"
        showFailure = true
        root.failed()
      }
      root.unlockInProgress = false
      passwordEntered = false
    }

    onError: {
      Logger.log("LockContext", "PAM error:", error, "message:", message)
      errorMessage = message || "Authentication error"
      showFailure = true
      root.unlockInProgress = false
      root.failed()
    }
  }
}
