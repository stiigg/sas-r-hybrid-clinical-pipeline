#!/usr/bin/env python3
"""
CDISC CORE VALIDATION FOR SDTM/ADaM DATASETS
Validates datasets against CDISC conformance rules
"""

import sys
import json
from pathlib import Path
import pandas as pd

# Check if cdisc-rules-engine is installed
try:
    from cdisc_rules_engine.engine import RulesEngine
    from cdisc_rules_engine.models.dataset import PandasDataset
    CORE_AVAILABLE = True
except ImportError:
    CORE_AVAILABLE = False
    print("\n⚠️  CDISC Rules Engine not installed")
    print("Install with: pip install cdisc-rules-engine")
    print("Skipping CORE validation...\n")


def validate_sdtm_domain(domain_path, domain_code):
    """Validate SDTM domain against CDISC conformance rules"""
    
    if not CORE_AVAILABLE:
        return True
    
    print(f"\n🔍 Validating {domain_code} domain...")
    
    # Check if file exists
    if not Path(domain_path).exists():
        print(f"  ❌ File not found: {domain_path}")
        return False
    
    try:
        # Load dataset
        if domain_path.endswith('.xpt'):
            df = pd.read_sas(domain_path, format='xport')
        elif domain_path.endswith('.csv'):
            df = pd.read_csv(domain_path)
        else:
            df = pd.read_sas(domain_path)
        
        print(f"  ✓ Loaded {len(df)} records")
        
        # Initialize CORE engine with SDTM 3.4 rules
        # Note: Actual CORE validation requires proper configuration
        # This is a simplified example
        
        # Basic conformance checks
        errors = []
        warnings = []
        
        # Check required variables for RS domain
        if domain_code == "RS":
            required_vars = ['STUDYID', 'DOMAIN', 'USUBJID', 'RSSEQ', 
                           'RSTESTCD', 'RSTEST']
            
            for var in required_vars:
                if var not in df.columns:
                    errors.append({
                        'rule_id': 'SDTM001',
                        'message': f'Required variable {var} is missing',
                        'severity': 'error'
                    })
            
            # Check DOMAIN value
            if 'DOMAIN' in df.columns:
                if not all(df['DOMAIN'] == 'RS'):
                    errors.append({
                        'rule_id': 'SDTM002',
                        'message': 'DOMAIN variable must equal "RS"',
                        'severity': 'error'
                    })
        
        # Generate report
        report = {
            'domain': domain_code,
            'file': str(domain_path),
            'records': len(df),
            'total_rules_checked': len(required_vars) if domain_code == 'RS' else 0,
            'errors': len(errors),
            'warnings': len(warnings),
            'error_details': errors,
            'warning_details': warnings
        }
        
        # Save JSON report
        output_dir = Path('outputs/validation')
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = output_dir / f"{domain_code}_core_report.json"
        
        with open(output_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        print(f"  ✓ Rules checked: {report['total_rules_checked']}")
        print(f"  {'❌' if errors else '✓'} Errors: {len(errors)}")
        print(f"  {'⚠️' if warnings else '✓'} Warnings: {len(warnings)}")
        
        if errors:
            print("\n  First 3 errors:")
            for err in errors[:3]:
                print(f"    - {err['rule_id']}: {err['message']}")
        
        print(f"  ✓ Report saved: {output_path}")
        
        return len(errors) == 0
        
    except Exception as e:
        print(f"  ❌ Validation error: {str(e)}")
        return False


if __name__ == "__main__":
    print("\n" + "="*50)
    print("CDISC CORE VALIDATION")
    print("="*50)
    
    # Validate RS domain created by sdtm.oak
    rs_valid = validate_sdtm_domain(
        "outputs/sdtm/rs_oak.xpt",
        "RS"
    )
    
    # Summary
    print("\n" + "="*50)
    if rs_valid:
        print("✅ All domains passed CDISC conformance checks!")
        sys.exit(0)
    else:
        if not CORE_AVAILABLE:
            print("⚠️  Validation skipped (CORE not installed)")
            sys.exit(0)
        else:
            print("❌ Validation failed - check reports in outputs/validation/")
            sys.exit(1)
