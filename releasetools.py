"""Device additions to the standard non-A/B OTA generator."""
import common


def FullOTA_InstallEnd(info):
    # Stock recovery auto-restoration was removed from vendor; install directly.
    info.script.WriteRawImage("/recovery", "recovery.img")
    # The stock AVB chain must be disabled for this unlocked bring-up build.
    image = info.input_zip.read("IMAGES/vbmeta.img")
    common.ZipWriteStr(info.output_zip, "vbmeta.img", image)
    info.script.WriteRawImage("/vbmeta", "vbmeta.img")
