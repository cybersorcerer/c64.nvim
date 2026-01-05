package output

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/cybersorcerer/c64.nvim/tools/c64u/internal/api"
)

// OutputMode represents the output format mode
type OutputMode int

const (
	// ModeText outputs human-readable text
	ModeText OutputMode = iota
	// ModeJSON outputs JSON
	ModeJSON
)

// Formatter handles output formatting
type Formatter struct {
	Mode OutputMode
}

// NewFormatter creates a new output formatter
func NewFormatter(jsonMode bool) *Formatter {
	mode := ModeText
	if jsonMode {
		mode = ModeJSON
	}
	return &Formatter{Mode: mode}
}

// Success prints a success message
func (f *Formatter) Success(message string, data map[string]interface{}) {
	if f.Mode == ModeJSON {
		output := map[string]interface{}{
			"success": true,
			"message": message,
		}
		if data != nil {
			output["data"] = data
		}
		f.printJSON(output)
	} else {
		fmt.Printf("✓ %s\n", message)
		if data != nil && len(data) > 0 {
			for key, value := range data {
				fmt.Printf("  %s: %v\n", key, value)
			}
		}
	}
}

// Error prints an error message and exits
func (f *Formatter) Error(message string, errors []string) {
	if f.Mode == ModeJSON {
		output := map[string]interface{}{
			"success": false,
			"message": message,
			"errors":  errors,
		}
		f.printJSON(output)
	} else {
		fmt.Fprintf(os.Stderr, "✗ Error: %s\n", message)
		if len(errors) > 0 {
			for _, err := range errors {
				fmt.Fprintf(os.Stderr, "  - %s\n", err)
			}
		}
	}
	os.Exit(1)
}

// PrintResponse formats and prints an API response
func (f *Formatter) PrintResponse(resp *api.Response, successMsg string) {
	if resp.HasErrors() {
		f.Error(successMsg+" failed", resp.Errors)
		return
	}

	f.Success(successMsg, resp.Data)
}

// PrintData prints arbitrary data
func (f *Formatter) PrintData(data interface{}) {
	if f.Mode == ModeJSON {
		f.printJSON(data)
	} else {
		// For text mode, format based on type
		switch v := data.(type) {
		case string:
			fmt.Println(v)
		case []string:
			for _, item := range v {
				fmt.Printf("  - %s\n", item)
			}
		case map[string]interface{}:
			for key, value := range v {
				fmt.Printf("  %s: %v\n", key, value)
			}
		default:
			fmt.Printf("%v\n", data)
		}
	}
}

// PrintTable prints data in a table format (text mode only)
func (f *Formatter) PrintTable(headers []string, rows [][]string) {
	if f.Mode == ModeJSON {
		// Convert table to JSON array of objects
		var jsonRows []map[string]string
		for _, row := range rows {
			jsonRow := make(map[string]string)
			for i, header := range headers {
				if i < len(row) {
					jsonRow[header] = row[i]
				}
			}
			jsonRows = append(jsonRows, jsonRow)
		}
		f.printJSON(jsonRows)
		return
	}

	// Calculate column widths
	widths := make([]int, len(headers))
	for i, h := range headers {
		widths[i] = len(h)
	}
	for _, row := range rows {
		for i, cell := range row {
			if i < len(widths) && len(cell) > widths[i] {
				widths[i] = len(cell)
			}
		}
	}

	// Print header
	for i, h := range headers {
		fmt.Printf("%-*s  ", widths[i], h)
	}
	fmt.Println()

	// Print separator
	for _, w := range widths {
		fmt.Print(strings.Repeat("-", w) + "  ")
	}
	fmt.Println()

	// Print rows
	for _, row := range rows {
		for i, cell := range row {
			if i < len(widths) {
				fmt.Printf("%-*s  ", widths[i], cell)
			}
		}
		fmt.Println()
	}
}

// printJSON marshals and prints JSON
func (f *Formatter) printJSON(data interface{}) {
	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(jsonData))
}

// Info prints an informational message (text mode only, silent in JSON mode)
func (f *Formatter) Info(message string) {
	if f.Mode == ModeText {
		fmt.Printf("ℹ %s\n", message)
	}
}

// Warning prints a warning message
func (f *Formatter) Warning(message string) {
	if f.Mode == ModeJSON {
		output := map[string]interface{}{
			"warning": message,
		}
		f.printJSON(output)
	} else {
		fmt.Fprintf(os.Stderr, "⚠ Warning: %s\n", message)
	}
}
