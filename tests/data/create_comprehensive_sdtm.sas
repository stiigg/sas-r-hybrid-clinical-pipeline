/* Comprehensive SDTM test data generator for RECIST validation */

data test.dm;
    length usubjid $20 arm $40 rfstdtc $10;
    
    /* Subject 001: CR confirmed */
    usubjid='001-001'; arm='Treatment A'; rfstdtc='2024-01-15'; output;
    /* [Add 20-25 subjects] */
run;

data test.rs;
    length usubjid $20 rsdtc $10 rstestcd $20 rsstresc $20;
    
    /* Subject 001: Investigator-reported responses */
    usubjid='001-001'; rsdtc='2024-01-15'; rstestcd='OVRLRESP'; rsstresc='CR'; output;
    usubjid='001-001'; rsdtc='2024-03-15'; rstestcd='OVRLRESP'; rsstresc='CR'; output;
run;

data test.tu;
    length usubjid $20 tulnkid $10 tuloc $40 tumethod $20;
    /* Tumor identification domain */
    usubjid='001-001'; tulnkid='TL01'; tuloc='RIGHT LUNG'; tumethod='CT SCAN'; output;
run;

data test.tr;
    length usubjid $20 trlnkid $10 trdtc $10 trorres $10 trorresu $10 trstat $20;
    /* Tumor results domain */
    usubjid='001-001'; trlnkid='TL01'; trdtc='2024-01-15'; 
    trorres='30'; trorresu='mm'; trlnkdia=30; trstat=''; output;
    
    usubjid='001-001'; trlnkid='TL01'; trdtc='2024-03-15'; 
    trorres='0'; trorresu='mm'; trlnkdia=0; trstat='ABSENT'; output;
run;
