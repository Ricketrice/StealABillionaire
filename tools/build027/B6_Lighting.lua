-- Studio location: ServerStorage.Build027.B6_Lighting (ModuleScript)
-- Bright sky, warm late-afternoon light ("dusk-style" warmth without darkness). The previous values
-- are in ServerStorage._Backups.Pre027_Phase2_2026-10-12.Lighting (attributes + effect copies).

local Lighting = game:GetService("Lighting")

return function(): string
	Lighting.ClockTime = 16.4
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(122, 112, 104)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 226, 190)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ExposureCompensation = 0.1
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
	atmosphere.Density = 0.24
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(226, 236, 255)
	atmosphere.Decay = Color3.fromRGB(255, 214, 170)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 0.6
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect", Lighting)
	bloom.Enabled, bloom.Intensity, bloom.Size, bloom.Threshold = true, 0.35, 22, 1.4
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Enabled, rays.Intensity, rays.Spread = true, 0.04, 0.6
	end
	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false -- blurs the Vault at the end of the lane
	end
	local cc = Lighting:FindFirstChild("SAB_ColorCorrection") or Instance.new("ColorCorrectionEffect", Lighting)
	cc.Brightness, cc.Contrast, cc.Saturation = 0.02, 0.06, 0.16
	cc.TintColor = Color3.fromRGB(255, 250, 244)
	return "lighting set"
end
