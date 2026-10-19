// Package names shares Unicode 16 canonical normalization with the Godot client.
package names

import (
	_ "embed"
	"encoding/json"
	"errors"
	"strconv"
	"unicode/utf8"

	"github.com/clipperhouse/uax29/v2/graphemes"
)

//go:embed unicode_nfc.json
var tableJSON []byte
var tables struct {
	Decomposition map[string][]int `json:"decomposition"`
	Combining     map[string]int   `json:"combining"`
	Composition   map[string]int   `json:"composition"`
}

func init() {
	if err := json.Unmarshal(tableJSON, &tables); err != nil {
		panic("invalid embedded Unicode tables")
	}
}

func class(point rune) int { return tables.Combining[strconv.Itoa(int(point))] }
func decompose(point rune, output *[]rune) {
	if point >= 0xac00 && point < 0xd7a4 {
		index := point - 0xac00
		*output = append(*output, 0x1100+index/588, 0x1161+(index%588)/28)
		if index%28 > 0 {
			*output = append(*output, 0x11a7+index%28)
		}
	} else if children, ok := tables.Decomposition[strconv.Itoa(int(point))]; ok {
		for _, child := range children {
			decompose(rune(child), output)
		}
	} else {
		*output = append(*output, point)
	}
}
func compose(first, second rune) (rune, bool) {
	if first >= 0x1100 && first < 0x1113 && second >= 0x1161 && second < 0x1176 {
		return 0xac00 + ((first-0x1100)*21+second-0x1161)*28, true
	}
	if first >= 0xac00 && first < 0xd7a4 && (first-0xac00)%28 == 0 && second > 0x11a7 && second < 0x11c3 {
		return first + second - 0x11a7, true
	}
	value, ok := tables.Composition[strconv.Itoa(int(first))+":"+strconv.Itoa(int(second))]
	return rune(value), ok
}

// NFC never inserts a stream-safe joiner into the player's name.
func NFC(value string) string {
	points := make([]rune, 0, len(value))
	for _, point := range value {
		decompose(point, &points)
	}
	for i := 1; i < len(points); i++ {
		order := class(points[i])
		for j := i; j > 0 && order > 0 && class(points[j-1]) > order; j-- {
			points[j], points[j-1] = points[j-1], points[j]
		}
	}
	if len(points) == 0 {
		return ""
	}
	output := []rune{points[0]}
	starter := points[0]
	at := 0
	previous := class(starter)
	for _, point := range points[1:] {
		current := class(point)
		combined, ok := compose(starter, point)
		if ok && (previous < current || previous == 0) {
			output[at] = combined
			starter = combined
		} else {
			if current == 0 {
				at = len(output)
				starter = point
			}
			output = append(output, point)
			previous = current
		}
	}
	return string(output)
}

func Validate(value string, maximum int) (string, error) {
	if !utf8.ValidString(value) || len(value) > 384 {
		return "", errors.New("invalid_name")
	}
	normalized := NFC(value)
	if len(normalized) > 96 {
		return "", errors.New("invalid_name")
	}
	iterator := graphemes.FromString(normalized)
	count := 0
	for iterator.Next() {
		count++
	}
	if count < 3 || count > maximum {
		return "", errors.New("invalid_name")
	}
	for _, point := range normalized {
		if point < 32 || point == 127 || point >= 0x80 && point <= 0x9f {
			return "", errors.New("invalid_name")
		}
		switch point {
		case '<', '>', '[', ']', 0x200b, 0x200e, 0x200f, 0x202a, 0x202b, 0x202c, 0x202d, 0x202e, 0x2066, 0x2067, 0x2068, 0x2069:
			return "", errors.New("invalid_name")
		}
	}
	return normalized, nil
}
