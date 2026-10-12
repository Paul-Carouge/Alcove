package media

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	_ "image/gif" // register decoders for image.DecodeConfig
	_ "image/jpeg"
	_ "image/png"
	"io"
	"math"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/evanoberholster/imagemeta"
	"github.com/evanoberholster/imagemeta/meta"
	_ "golang.org/x/image/webp"

	"github.com/Paul-Carouge/Alcove/server/internal/ffbundle"
)

// Info is what we extract from a photo or video.
type Info struct {
	Taken       time.Time
	Width       int
	Height      int
	Duration    float64
	Make        string
	Model       string
	Lens        string
	Exposure    string
	HasLocation bool
	Lat, Lon    float64
	Orientation int // EXIF orientation (1–8, 0 when unknown), for the Go thumbnailer
}

// ffmpegTimeout bounds every external call (files are untrusted).
var ffmpegTimeout = 2 * time.Minute

// HaveFFmpeg reports whether ffmpeg and ffprobe are installed.
func HaveFFmpeg() bool {
	_, e1 := exec.LookPath("ffmpeg")
	_, e2 := exec.LookPath("ffprobe")
	return e1 == nil && e2 == nil
}

// HEICSupported reports whether the installed ffmpeg decodes HEIC as saved by phones (tiled HEIF,
// ffmpeg 7.1+). Checked per file, so installing a newer ffmpeg needs no restart.
func HEICSupported() bool { return ffbundle.System().Recent() }

// ImageInfo reads EXIF metadata. The size comes from the image header when Go can decode it (EXIF
// dimensions go stale when a picture is edited), from EXIF otherwise (HEIC).
func ImageInfo(path string) (Info, error) {
	f, err := os.Open(path) // #nosec G304 -- temp copy made by the worker
	if err != nil {
		return Info{}, err
	}
	defer func() { _ = f.Close() }()

	var info Info
	var exifW, exifH int
	rotated := false
	if e, err := imagemeta.Decode(f); err == nil {
		info.Taken = e.OriginalDate()
		if info.Taken.IsZero() {
			info.Taken = e.DigitizedDate()
		}
		info.Make = strings.TrimSpace(e.IFD0.Make)
		info.Model = strings.TrimSpace(e.IFD0.Model)
		info.Lens = strings.TrimSpace(e.ExifIFD.LensModel)
		exifW, exifH = int(e.ExifIFD.PixelXDimension), int(e.ExifIFD.PixelYDimension)
		if exifW == 0 {
			exifW, exifH = int(e.IFD0.ImageWidth), int(e.IFD0.ImageHeight)
		}
		o := e.IFD0.Orientation
		rotated = o >= meta.OrientationMirrorHorizontalRotate270 && o <= meta.OrientationRotate270
		info.Orientation = int(o)
		lat, lon := e.GPS.Latitude(), e.GPS.Longitude()
		if (lat != 0 || lon != 0) && math.Abs(lat) <= 90 && math.Abs(lon) <= 180 {
			info.HasLocation, info.Lat, info.Lon = true, lat, lon
		}
		info.Exposure = exposure(e.ExifIFD.ExposureTime.String(), e.ExifIFD.FNumber.String(), e.ExifIFD.ISOSpeedRatings, e.ExifIFD.FocalLength.String())
	}
	if _, err := f.Seek(0, io.SeekStart); err == nil {
		if cfg, _, err := image.DecodeConfig(f); err == nil {
			info.Width, info.Height = cfg.Width, cfg.Height
		}
	}
	if info.Width == 0 {
		info.Width, info.Height = exifW, exifH
	}
	// Orientations 5–8 rotate by 90°: store the displayed size.
	if rotated {
		info.Width, info.Height = info.Height, info.Width
	}
	return info, nil
}

func exposure(shutter, aperture string, iso uint32, focal string) string {
	var parts []string
	clean := func(s string) string {
		if s == "" || s == "0" || s == "0s" || strings.HasPrefix(s, "0/") || s == "f/0.0" || s == "0.00mm" || s == "0mm" {
			return ""
		}
		return s
	}
	for _, p := range []string{clean(shutter), clean(aperture)} {
		if p != "" {
			parts = append(parts, p)
		}
	}
	if iso > 0 {
		parts = append(parts, "ISO "+strconv.Itoa(int(iso)))
	}
	if f := clean(focal); f != "" {
		parts = append(parts, f)
	}
	return strings.Join(parts, " · ")
}

// --- ffprobe / ffmpeg ---

type probeOutput struct {
	Streams []struct {
		CodecType    string            `json:"codec_type"`
		Width        int               `json:"width"`
		Height       int               `json:"height"`
		Tags         map[string]string `json:"tags"`
		SideDataList []struct {
			Rotation float64 `json:"rotation"`
		} `json:"side_data_list"`
	} `json:"streams"`
	Format struct {
		Duration string            `json:"duration"`
		Tags     map[string]string `json:"tags"`
	} `json:"format"`
}

// iso6709 matches "+48.8584-002.2945+035.000/" (QuickTime location tags).
var iso6709 = regexp.MustCompile(`^([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)`)

// VideoInfo reads duration, size, date and location with ffprobe.
func VideoInfo(ctx context.Context, path string) (Info, error) {
	ctx, cancel := context.WithTimeout(ctx, ffmpegTimeout)
	defer cancel()
	out, err := exec.CommandContext(ctx, "ffprobe", "-v", "error", "-print_format", "json",
		"-show_format", "-show_streams", "--", path).Output() // #nosec G204 -- fixed binary, path from the worker
	if err != nil {
		return Info{}, fmt.Errorf("ffprobe: %w", err)
	}
	var p probeOutput
	if err := json.Unmarshal(out, &p); err != nil {
		return Info{}, err
	}
	var info Info
	info.Duration, _ = strconv.ParseFloat(p.Format.Duration, 64)
	tags := map[string]string{}
	for k, v := range p.Format.Tags {
		tags[strings.ToLower(k)] = v
	}
	for _, s := range p.Streams {
		if s.CodecType != "video" || info.Width != 0 {
			continue
		}
		info.Width, info.Height = s.Width, s.Height
		rot := 0.0
		for _, sd := range s.SideDataList {
			rot = sd.Rotation
		}
		if r, err := strconv.ParseFloat(s.Tags["rotate"], 64); err == nil {
			rot = r
		}
		if int(math.Abs(rot))%180 == 90 {
			info.Width, info.Height = info.Height, info.Width
		}
		for k, v := range s.Tags {
			if _, ok := tags[strings.ToLower(k)]; !ok {
				tags[strings.ToLower(k)] = v
			}
		}
	}
	// Values may hold several dates separated by ";" (duplicated tags).
	for _, key := range []string{"com.apple.quicktime.creationdate", "creation_time", "date"} {
		for _, v := range strings.Split(tags[key], ";") {
			if t := parseDate(strings.TrimSpace(v)); !t.IsZero() {
				info.Taken = t
				break
			}
		}
		if !info.Taken.IsZero() {
			break
		}
	}
	for _, key := range []string{"com.apple.quicktime.location.iso6709", "location"} {
		if m := iso6709.FindStringSubmatch(tags[key]); m != nil {
			lat, _ := strconv.ParseFloat(m[1], 64)
			lon, _ := strconv.ParseFloat(m[2], 64)
			if math.Abs(lat) <= 90 && math.Abs(lon) <= 180 && (lat != 0 || lon != 0) {
				info.HasLocation, info.Lat, info.Lon = true, lat, lon
				break
			}
		}
	}
	info.Make, info.Model = tags["com.apple.quicktime.make"], tags["com.apple.quicktime.model"]
	return info, nil
}

func parseDate(v string) time.Time {
	for _, layout := range []string{time.RFC3339Nano, "2006-01-02T15:04:05-0700", "2006-01-02 15:04:05"} {
		if t, err := time.Parse(layout, v); err == nil && t.Year() > 1970 {
			return t
		}
	}
	return time.Time{}
}

// Derivatives writes a grid thumbnail (360 px high) and a viewer preview
// (fits 1600×1600) as JPEG. For videos the frame comes from 10% in (≤ 3 s).
func Derivatives(ctx context.Context, src, thumb, preview string, video bool, duration float64) error {
	var seek []string
	if video {
		at := math.Min(3, duration/10)
		seek = []string{"-ss", strconv.FormatFloat(at, 'f', 2, 64)}
	}
	run := func(dst, scale string) error {
		ctx, cancel := context.WithTimeout(ctx, ffmpegTimeout)
		defer cancel()
		args := append([]string{"-nostdin", "-hide_banner", "-loglevel", "error", "-threads", "2"}, seek...)
		args = append(args, "-i", src, "-frames:v", "1", "-vf", scale, "-q:v", "4", "-y", dst)
		var stderr bytes.Buffer
		cmd := exec.CommandContext(ctx, "ffmpeg", args...) // #nosec G204 -- fixed binary and arguments
		cmd.Stderr = &stderr
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("ffmpeg: %w: %s", err, strings.TrimSpace(lastLine(stderr.String())))
		}
		if info, err := os.Stat(dst); err != nil || info.Size() == 0 {
			return errors.New("ffmpeg produced no image")
		}
		return nil
	}
	if err := run(thumb, "scale=-2:360"); err != nil {
		return err
	}
	return run(preview, "scale=w=1600:h=1600:force_original_aspect_ratio=decrease:force_divisible_by=2")
}

func lastLine(s string) string {
	lines := strings.Split(strings.TrimSpace(s), "\n")
	return lines[len(lines)-1]
}
