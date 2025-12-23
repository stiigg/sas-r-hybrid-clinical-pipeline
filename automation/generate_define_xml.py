#!/usr/bin/env python3
"""
Define-XML Generator using odmlib
Generates CDISC Define-XML v2.1 from study metadata for RECIST 1.1 implementation

Part of CDISC 360i automation pipeline
References:
- odmlib: https://github.com/swhume/odmlib
- Define-XML v2.1: https://www.cdisc.org/standards/data-exchange/define-xml
"""

from odmlib.define_2_1 import model as ODM
import json
from datetime import datetime
from pathlib import Path
import sys

def create_study_metadata():
    """Create ODM Study root with metadata"""
    
    # Create ODM root element
    odm = ODM.ODM(
        FileOID=f"DEFINE-RECIST-{datetime.now().strftime('%Y%m%d')}",
        FileType="Snapshot",
        CreationDateTime=datetime.now().isoformat(),
        ODMVersion="1.3.2",
        Originator="SAS-R Hybrid Pipeline",
        SourceSystem="odmlib + pharmaverse",
        SourceSystemVersion="1.0.0"
    )
    
    # Create study
    study = ODM.Study(
        OID="RECIST-DEMO-001",
        StudyName="RECIST 1.1 Demonstration Study",
        StudyDescription="Oncology trial demonstrating automated SDTM/ADaM generation with pharmaverse",
        ProtocolName="RECIST-DEMO-001"
    )
    
    # Create global variables
    global_vars = ODM.GlobalVariables(
        StudyName="RECIST 1.1 Demo",
        StudyDescription="Automated clinical pipeline demonstration",
        ProtocolName="RECIST-DEMO-001"
    )
    study.GlobalVariables = global_vars
    
    # Create metadata version
    mdv = ODM.MetaDataVersion(
        OID="MDV.RECIST-DEMO.SDTM.1.0",
        Name="SDTM Metadata Version 1.0",
        Description="RECIST 1.1 SDTM implementation with sdtm.oak automation",
        DefineVersion="2.1"
    )
    
    # Add standard information
    mdv.Standard = []
    mdv.Standard.append(ODM.Standard(
        OID="STD.SDTM.1",
        Name="SDTMIG",
        Type="IG",
        Version="3.4",
        PublishingSet="CDISC",
        Status="Final"
    ))
    
    mdv.Standard.append(ODM.Standard(
        OID="STD.CT.1",
        Name="SDTM",
        Type="CT",
        Version="2024-09-27",
        PublishingSet="CDISC",
        Status="Final"
    ))
    
    study.MetaDataVersion.append(mdv)
    odm.Study.append(study)
    
    return odm, mdv

def create_rs_domain(mdv):
    """Create RS (Disease Response) domain definition"""
    
    # Define RS domain
    rs_domain = ODM.ItemGroupDef(
        OID="IG.RS",
        Name="RS",
        Repeating="Yes",
        IsReferenceData="No",
        SASDatasetName="RS",
        Domain="RS",
        Purpose="Tabulation",
        Structure="One record per tumor response assessment per subject",
        DomainKeys="STUDYID, USUBJID, RSTESTCD, RSSEQ",
        Label="Disease Response"
    )
    
    # Add class and comment
    rs_domain.Class = ODM.Class(
        Name="Findings"
    )
    
    # Define RS variables with CDISC standards
    rs_variables = [
        {
            "name": "STUDYID",
            "label": "Study Identifier",
            "datatype": "text",
            "length": 12,
            "core": "Req",
            "origin": "Assigned",
            "comment": "Unique identifier for the study"
        },
        {
            "name": "DOMAIN",
            "label": "Domain Abbreviation",
            "datatype": "text",
            "length": 2,
            "core": "Req",
            "origin": "Assigned",
            "comment": "Two-character abbreviation for the domain (RS)"
        },
        {
            "name": "USUBJID",
            "label": "Unique Subject Identifier",
            "datatype": "text",
            "length": 40,
            "core": "Req",
            "origin": "Assigned",
            "comment": "Identifier used to uniquely identify a subject across all studies"
        },
        {
            "name": "RSSEQ",
            "label": "Sequence Number",
            "datatype": "integer",
            "length": 8,
            "core": "Req",
            "origin": "Assigned",
            "comment": "Sequence number for ordering records within a subject"
        },
        {
            "name": "RSTESTCD",
            "label": "Response Assessment Short Name",
            "datatype": "text",
            "length": 8,
            "core": "Req",
            "origin": "Assigned",
            "comment": "Short name for tumor response assessment (e.g., TUMIDENT, OVR)"
        },
        {
            "name": "RSTEST",
            "label": "Response Assessment Name",
            "datatype": "text",
            "length": 40,
            "core": "Req",
            "origin": "Assigned",
            "comment": "Full name of tumor response assessment"
        },
        {
            "name": "RSCAT",
            "label": "Category for Response",
            "datatype": "text",
            "length": 40,
            "core": "Perm",
            "origin": "Assigned",
            "comment": "Category grouping for response assessments (e.g., RECIST 1.1)"
        },
        {
            "name": "RSORRES",
            "label": "Result in Original Units",
            "datatype": "text",
            "length": 200,
            "core": "Exp",
            "origin": "CRF",
            "comment": "Result as collected on CRF or EDC"
        },
        {
            "name": "RSSTRESC",
            "label": "Character Result/Finding in Std Format",
            "datatype": "text",
            "length": 200,
            "core": "Exp",
            "origin": "Derived",
            "comment": "Standardized result (CR, PR, SD, PD for RECIST)"
        },
        {
            "name": "RSSTRESN",
            "label": "Numeric Result/Finding in Standard Units",
            "datatype": "float",
            "length": 8,
            "core": "Exp",
            "origin": "Derived",
            "comment": "Numeric representation of result if applicable"
        },
        {
            "name": "VISITNUM",
            "label": "Visit Number",
            "datatype": "integer",
            "length": 8,
            "core": "Exp",
            "origin": "Assigned",
            "comment": "Numeric identifier for visit"
        },
        {
            "name": "VISIT",
            "label": "Visit Name",
            "datatype": "text",
            "length": 40,
            "core": "Perm",
            "origin": "Assigned",
            "comment": "Protocol-defined description of visit"
        },
        {
            "name": "RSDTC",
            "label": "Date/Time of Response Assessment",
            "datatype": "datetime",
            "length": 20,
            "core": "Exp",
            "origin": "CRF",
            "comment": "Date/time of assessment in ISO8601 format"
        },
        {
            "name": "RSDY",
            "label": "Study Day of Response Assessment",
            "datatype": "integer",
            "length": 8,
            "core": "Perm",
            "origin": "Derived",
            "comment": "Study day relative to reference start date"
        }
    ]
    
    # Create ItemDefs and add to domain
    for idx, var in enumerate(rs_variables, start=1):
        # Create ItemDef
        item_def = ODM.ItemDef(
            OID=f"IT.RS.{var['name']}",
            Name=var['name'],
            DataType=var['datatype'],
            Length=var['length'],
            SASFieldName=var['name'],
            SDSVarName=var['name'],
            Origin=ODM.Origin(
                Type=var['origin']
            ),
            Label=var['label'],
            Comment=var['comment']
        )
        
        # Add to metadata version
        mdv.ItemDef.append(item_def)
        
        # Create ItemRef for domain
        item_ref = ODM.ItemRef(
            ItemOID=f"IT.RS.{var['name']}",
            Mandatory="Yes" if var['core'] == "Req" else "No",
            OrderNumber=idx,
            Role=var['core']
        )
        
        rs_domain.ItemRef.append(item_ref)
    
    # Add domain to metadata version
    mdv.ItemGroupDef.append(rs_domain)
    
    return rs_domain

def generate_define_xml_for_recist():
    """Main function to generate Define-XML for RECIST study"""
    
    print("\n🔧 Generating Define-XML v2.1 with odmlib...")
    print("=" * 60)
    
    # Create study metadata
    odm, mdv = create_study_metadata()
    print(f"✓ Created ODM root: {odm.FileOID}")
    print(f"✓ Study: {odm.Study[0].StudyName}")
    
    # Create RS domain
    rs_domain = create_rs_domain(mdv)
    print(f"\n✓ Created RS domain with {len(rs_domain.ItemRef)} variables")
    
    # Create output directory
    output_dir = Path("outputs/specs")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate XML output
    xml_path = output_dir / "define_rs.xml"
    try:
        with open(xml_path, 'w', encoding='utf-8') as f:
            f.write(odm.to_xml())
        print(f"\n✅ Define-XML generated: {xml_path}")
        print(f"   Size: {xml_path.stat().st_size:,} bytes")
    except Exception as e:
        print(f"\n❌ XML generation failed: {e}")
        return False
    
    # Generate JSON output
    json_path = output_dir / "define_rs.json"
    try:
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(odm.to_dict(), f, indent=2)
        print(f"✅ Define-JSON generated: {json_path}")
        print(f"   Size: {json_path.stat().st_size:,} bytes")
    except Exception as e:
        print(f"⚠️  JSON generation warning: {e}")
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 Define-XML Summary:")
    print(f"   - Standard: SDTM IG v3.4")
    print(f"   - Controlled Terminology: 2024-09-27")
    print(f"   - Domains: RS (Disease Response)")
    print(f"   - Variables: {len(rs_domain.ItemRef)}")
    print(f"   - Format: Define-XML v2.1")
    print(f"   - Generated by: odmlib + pharmaverse")
    print("\n✅ Define-XML generation complete!\n")
    
    return True

if __name__ == "__main__":
    try:
        success = generate_define_xml_for_recist()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
