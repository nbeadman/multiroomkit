import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";

const script = await readFile(path.resolve("site/assets/sonos-callback.js"), "utf8");

function runCallback(query, { failToClear = false } = {}) {
  const elements = new Map(
    ["status", "result", "authorization-code", "authorization-state"].map((id) => [
      id,
      { textContent: "", value: "", hidden: id === "result" },
    ]),
  );
  const events = [];
  vm.runInNewContext(script, {
    URLSearchParams,
    document: {
      getElementById(id) {
        return elements.get(id);
      },
    },
    window: {
      location: { search: query, pathname: "/multiroomkit/sonos/callback/" },
      history: {
        replaceState(...arguments_) {
          events.push(["clear", ...arguments_]);
          if (failToClear) throw new Error("history unavailable");
        },
      },
    },
  });
  return { elements, events };
}

test("shows code and state only after clearing the URL", () => {
  const { elements, events } = runCallback("?code=private-code&state=private-state");
  assert.deepEqual(events, [["clear", null, "", "/multiroomkit/sonos/callback/"]]);
  assert.equal(elements.get("authorization-code").value, "private-code");
  assert.equal(elements.get("authorization-state").value, "private-state");
  assert.equal(elements.get("result").hidden, false);
});

test("does not expose a code if the URL cannot be cleared", () => {
  const { elements } = runCallback("?code=private-code&state=private-state", { failToClear: true });
  assert.equal(elements.get("authorization-code").value, "");
  assert.equal(elements.get("result").hidden, true);
  assert.match(elements.get("status").textContent, /Close this tab/);
});

test("handles denial and incomplete responses without showing a code", () => {
  for (const query of ["?error=access_denied&state=private-state", "?code=private-code", ""]) {
    const { elements, events } = runCallback(query);
    assert.equal(events.length, 1);
    assert.equal(elements.get("authorization-code").value, "");
    assert.equal(elements.get("result").hidden, true);
  }
});
