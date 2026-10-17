# Vault wizard in-engine tests (Studio MCP `execute_luau`, one at a time; `tools/kill_tests.sh --check` before, `tools/kill_tests.sh` after)
Setup (Edit): scripts pushed with `tools/push_to_studio.py $(find src/ServerStorage/VaultWizardTest src/ServerScriptService/DevTest_Vault035* -name '*.lua')`; `Builder.build(ServerStorage.VaultWizardTest.Imported.VaultWizard)` -> `Template` (require a CLONE of edited modules: Studio caches require results).
Solo Play (Server DM): `Harness.spawn()`, `Harness.bringPlayers(m)` (StreamingEnabled hides things 900 studs up), then
1. Server poses: for each clip and sample 1..4 `Checks.poseOnServer(m, clip, i)` (NaN counts as failure) -> max pivot error vs glTF FK (`Tests/Expected`).
2. Client poses (Client DM): server `Checks.freeze(m, clip, i)`, wait 0.8 s, client `require(m.Runtime.Probe).measure(m)`; `Checks.unfreeze`.
3. Live: server `Harness.play(m, clip)` for each clip; client samples `Probe.vfx(m)` every 0.05 s: effects appear at their authored times, all temporaries gone 3 s after, aura stays (3 emitters).
4. Walk: `Harness.walk(m, to, 8)`; client reads LeftHip Transform swing and root displacement.
5. Replication probe: wizard clone without the Client script, server sets `LeftUpperArm.LeftShoulder.Transform`, client reads it.
6. Animator comparison: KeyframeSequence from the clip table -> `KeyframeSequenceProvider:RegisterKeyframeSequence` -> `AnimationController.Animator:LoadAnimation` on the server.
7. Perf: client `RenderStepped` dt over 6 s with 1 / 5 / 20 wizards (`Harness.spawn(offset)`, all on Walk); triangle counts through `AssetService:CreateEditableMeshAsync(Content.fromUri(MeshId))`.
Two clients: `ServerScriptService.DevTest_Vault035` (arg `vault035`): launch from Edit with `task.spawn(function() game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, "vault035") end)` after `TAG=TVW tools/test_guard.sh vault035 600`. Needs swap headroom (the guard stops at < 5 GB free swap).
