// Package mediatest builds photos with real EXIF metadata for tests.
package mediatest

import (
	"bytes"
	"encoding/binary"
	"image"
	"image/color"
	"image/jpeg"
	"math"
	"time"
)

// Photo describes the metadata written into a test JPEG.
type Photo struct {
	Width, Height int
	Taken         time.Time // zero: no date
	Make, Model   string
	Lat, Lon      float64 // both zero: no GPS
	Orientation   uint16  // 0: omitted
}

type entry struct {
	tag, typ uint16
	count    uint32
	data     []byte // raw value bytes (little endian)
}

const (
	tASCII    = 2
	tShort    = 3
	tLong     = 4
	tRational = 5
)

func ascii(s string) entry {
	return entry{typ: tASCII, count: uint32(len(s) + 1), data: append([]byte(s), 0)}
}

func short(v uint16) entry {
	b := make([]byte, 2)
	binary.LittleEndian.PutUint16(b, v)
	return entry{typ: tShort, count: 1, data: b}
}

func long(v uint32) entry {
	b := make([]byte, 4)
	binary.LittleEndian.PutUint32(b, v)
	return entry{typ: tLong, count: 1, data: b}
}

// dms encodes decimal degrees as three rationals (deg, min, sec*1000/1000).
func dms(v float64) entry {
	v = math.Abs(v)
	d := math.Floor(v)
	m := math.Floor((v - d) * 60)
	s := ((v-d)*60 - m) * 60
	b := make([]byte, 24)
	for i, pair := range [][2]uint32{{uint32(d), 1}, {uint32(m), 1}, {uint32(math.Round(s * 10000)), 10000}} {
		binary.LittleEndian.PutUint32(b[i*8:], pair[0])
		binary.LittleEndian.PutUint32(b[i*8+4:], pair[1])
	}
	return entry{typ: tRational, count: 3, data: b}
}

func with(tag uint16, e entry) entry { e.tag = tag; return e }

func ifdSize(n int) uint32 { return uint32(2 + 12*n + 4) }

// tiff lays out IFD0, Exif IFD and GPS IFD followed by their data.
func tiff(p Photo) []byte {
	ifd0 := []entry{}
	if p.Make != "" {
		ifd0 = append(ifd0, with(0x010F, ascii(p.Make)))
	}
	if p.Model != "" {
		ifd0 = append(ifd0, with(0x0110, ascii(p.Model)))
	}
	if p.Orientation != 0 {
		ifd0 = append(ifd0, with(0x0112, short(p.Orientation)))
	}
	exif := []entry{}
	if !p.Taken.IsZero() {
		exif = append(exif, with(0x9003, ascii(p.Taken.Format("2006:01:02 15:04:05"))))
	}
	exif = append(exif, with(0xA002, long(uint32(p.Width))), with(0xA003, long(uint32(p.Height))))
	var gps []entry
	if p.Lat != 0 || p.Lon != 0 {
		latRef, lonRef := "N", "E"
		if p.Lat < 0 {
			latRef = "S"
		}
		if p.Lon < 0 {
			lonRef = "W"
		}
		gps = []entry{with(1, ascii(latRef)), with(2, dms(p.Lat)), with(3, ascii(lonRef)), with(4, dms(p.Lon))}
	}
	nIFD0 := len(ifd0) + 1 // + Exif pointer
	if gps != nil {
		nIFD0++
	}
	off0 := uint32(8)
	offExif := off0 + ifdSize(nIFD0)
	offGPS := offExif + ifdSize(len(exif))
	dataStart := offGPS
	if gps != nil {
		dataStart += ifdSize(len(gps))
	}
	ifd0 = append(ifd0, with(0x8769, long(offExif)))
	if gps != nil {
		ifd0 = append(ifd0, with(0x8825, long(offGPS)))
	}

	var data bytes.Buffer
	writeIFD := func(buf *bytes.Buffer, entries []entry) {
		_ = binary.Write(buf, binary.LittleEndian, uint16(len(entries)))
		for _, e := range entries {
			_ = binary.Write(buf, binary.LittleEndian, e.tag)
			_ = binary.Write(buf, binary.LittleEndian, e.typ)
			_ = binary.Write(buf, binary.LittleEndian, e.count)
			if len(e.data) <= 4 {
				v := make([]byte, 4)
				copy(v, e.data)
				buf.Write(v)
			} else {
				_ = binary.Write(buf, binary.LittleEndian, dataStart+uint32(data.Len()))
				data.Write(e.data)
				if data.Len()%2 == 1 {
					data.WriteByte(0)
				}
			}
		}
		_ = binary.Write(buf, binary.LittleEndian, uint32(0))
	}
	var out bytes.Buffer
	out.WriteString("II*\x00")
	_ = binary.Write(&out, binary.LittleEndian, off0)
	writeIFD(&out, ifd0)
	writeIFD(&out, exif)
	if gps != nil {
		writeIFD(&out, gps)
	}
	out.Write(data.Bytes())
	return out.Bytes()
}

// JPEG returns a gradient image with the EXIF metadata of p.
func JPEG(p Photo) []byte {
	img := image.NewRGBA(image.Rect(0, 0, p.Width, p.Height))
	for y := range p.Height {
		for x := range p.Width {
			img.Set(x, y, color.RGBA{uint8(x * 255 / max(1, p.Width)), uint8(y * 255 / max(1, p.Height)), 160, 255})
		}
	}
	var enc bytes.Buffer
	_ = jpeg.Encode(&enc, img, &jpeg.Options{Quality: 80})
	raw := enc.Bytes()
	app1 := append([]byte("Exif\x00\x00"), tiff(p)...)
	var out bytes.Buffer
	out.Write(raw[:2]) // SOI
	out.Write([]byte{0xFF, 0xE1})
	_ = binary.Write(&out, binary.BigEndian, uint16(len(app1)+2))
	out.Write(app1)
	out.Write(raw[2:])
	return out.Bytes()
}
