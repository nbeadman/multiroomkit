(() => {
  const parameters = new URLSearchParams(window.location.search);
  const code = parameters.get("code");
  const state = parameters.get("state");
  const error = parameters.get("error");
  const status = document.getElementById("status");

  // Remove the authorization response from the address bar before displaying it.
  // No query values are logged, stored, or sent to another endpoint.
  try {
    window.history.replaceState(null, "", window.location.pathname);
  } catch {
    status.textContent = "Could not clear the private response from the address bar. Close this tab and try again.";
    return;
  }

  if (error) {
    status.textContent = "Sonos authorization was not completed (" + error.slice(0, 120) + ").";
    return;
  }
  if (!code || !state) {
    status.textContent = "No complete Sonos authorization response was found. Start from a local authorization request.";
    return;
  }

  document.getElementById("authorization-code").value = code;
  document.getElementById("authorization-state").value = state;
  document.getElementById("result").hidden = false;
  status.textContent = "Authorization response received. Compare the state before using the code.";
})();
