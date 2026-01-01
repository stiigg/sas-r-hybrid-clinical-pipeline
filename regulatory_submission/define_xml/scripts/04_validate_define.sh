#!/bin/bash
################################################################################
# Validate Define-XML with Pinnacle 21 Community
################################################################################

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"

DEFINE_XML="$PROJECT_ROOT/regulatory_submission/define_xml/outputs/define_sdtm.xml"
XPT_DIR="$PROJECT_ROOT/regulatory_submission/define_xml/metadata/xpt_files"
REPORT_DIR="$PROJECT_ROOT/regulatory_submission/define_xml/outputs/validation_reports"
P21_JAR="/opt/pinnacle21/P21Community.jar"

# Create report directory
mkdir -p "$REPORT_DIR"

echo "═══════════════════════════════════════════════════════════════════"
echo "  Pinnacle 21 Community Define-XML Validation"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Check if Pinnacle 21 is installed
if [ ! -f "$P21_JAR" ]; then
    echo "⚠ Pinnacle 21 Community not found at: $P21_JAR"
    echo ""
    echo "Download from: https://www.pinnacle21.com/downloads"
    echo "Or update P21_JAR path in this script"
    echo ""
    
    # Try to find P21 in common locations
    echo "Searching for Pinnacle 21 in common locations..."
    for location in /Applications/Pinnacle21*/P21Community.jar ~/pinnacle21/P21Community.jar /usr/local/pinnacle21/P21Community.jar; do
        if [ -f "$location" ]; then
            echo "✓ Found Pinnacle 21 at: $location"
            P21_JAR="$location"
            break
        fi
    done
    
    if [ ! -f "$P21_JAR" ]; then
        echo "✗ Pinnacle 21 not found. Please install or update P21_JAR path."
        exit 1
    fi
fi

# Check if Define-XML exists
if [ ! -f "$DEFINE_XML" ]; then
    echo "⚠ Define-XML not found: $DEFINE_XML"
    echo "Run: Rscript regulatory_submission/define_xml/generate_define_sdtm.R"
    exit 1
fi

# Check if XPT files exist
if [ ! -d "$XPT_DIR" ] || [ -z "$(ls -A $XPT_DIR/*.xpt 2>/dev/null)" ]; then
    echo "⚠ No XPT files found in: $XPT_DIR"
    echo "XPT files required for validation"
    exit 1
fi

echo "Validation Configuration:"
echo "  Define-XML: $(basename $DEFINE_XML)"
echo "  XPT Directory: $XPT_DIR"
echo "  XPT Files Found: $(ls $XPT_DIR/*.xpt 2>/dev/null | wc -l)"
echo "  Report Directory: $REPORT_DIR"
echo ""

# Run Pinnacle 21 validation
echo "Running Pinnacle 21 validation..."
echo ""

java -Xmx4G -jar "$P21_JAR" \
    --task=validate \
    --type=SDTMIG \
    --version=3.4 \
    --define="$DEFINE_XML" \
    --data="$XPT_DIR" \
    --report="$REPORT_DIR/validation_report" \
    2>&1 | tee "$REPORT_DIR/validation_log.txt"

VALIDATION_STATUS=$?

echo ""
echo "═══════════════════════════════════════════════════════════════════"

if [ $VALIDATION_STATUS -eq 0 ]; then
    echo "✓ Validation Complete"
else
    echo "⚠ Validation completed with errors/warnings"
    echo "Check report for details"
fi

echo ""
echo "Output Files:"
echo "  Report: $REPORT_DIR/validation_report.html"
echo "  Log: $REPORT_DIR/validation_log.txt"
echo ""
echo "═══════════════════════════════════════════════════════════════════"

# Open report in browser (cross-platform)
if command -v open &> /dev/null; then
    # macOS
    open "$REPORT_DIR/validation_report.html" 2>/dev/null || true
elif command -v xdg-open &> /dev/null; then
    # Linux
    xdg-open "$REPORT_DIR/validation_report.html" 2>/dev/null || true
elif command -v start &> /dev/null; then
    # Windows (Git Bash)
    start "$REPORT_DIR/validation_report.html" 2>/dev/null || true
fi

exit $VALIDATION_STATUS
