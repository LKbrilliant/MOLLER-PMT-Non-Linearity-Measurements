#!/bin/bash
# Code by:    Anuradha Gunawardhana
# Date:       2023.11.30
# Details:    The script is used to check the max anode current of a PMT for a given LED voltage. 
#             This will use the open filter position(9) to measure the max anode current and the blackout 
#             position for pedestal data. This is use as an alternative methode to check the max current to 
#             save time without doing a full non-linearity measurement.

base_dir='Test_Data'
filter_order=( '4' '11' '8' '2' '9' '7' '3' '5' '1' '6' '10' '12' )
pedestal_count=0
directoryCreated=false
SECONDS=0

function usage {
  echo ""
  echo "------------------------------------------"
  echo "|  Max anode current measurement : Usage  |"
  echo "------------------------------------------"
  echo ""
  echo "Code by: Anuradha Gunawardhana"
  echo "Date: 10.06.2024"
  echo "Version: 0.4"
  echo ""
  echo "Usage: $0 -vc|--vconst <voltage> -hv|--highVolt <voltage> -g|--gain <preamp-gain> -s|--serial <serial> -ts|--timeStamp <time-stamp> -d|--dir <directory>"
  echo ""
  echo "Options:"
  echo "  -vc, --vconst     Constant LED voltage (0-5)V."
  echo "  -hv, --highVolt   PMT high voltage (0-1000)V"
  echo "  -g,  --gain       Pre-amp gain setting (20k, 100k, 200k, 1M)"
  echo "  -s,  --serial     PMT serial number"
  echo "  -b,  --base       Number of stages in the base (3,4)"
  echo "  -Ic, --Icahode    Cathode current at max brightness (100% light transmission)"
  echo "  -ts, --timeStamp  Time stamp of PMT powerd on time (YYYYMMDDhhmm)"
  echo "  -tr, --testRun    Test run or not (true,false)"
  echo "  -d,  --dir        [Optional] Data directory name. Will create a folder -d inside 'base_dir'"

  exit 1
}

while [[ $# -gt 0 ]] ; do
  case "$1" in
    -vc | --vconst)
      VC="$2"
      shift
      shift
      ;;
    -hv | --highVolt)
      HV="$2"
      shift
      shift
      ;;
    -g | --gain)
      GAIN="$2"
      shift
      shift
      ;;
    -s | --serial)
      SERIAL="$2"
      shift
      shift
      ;;
    -b | --base)
      BASE="$2"
      shift
      shift
      ;;
    -d | --dir)
      DIR="$2"
      shift
      shift
      ;;
    -Ic | --Icathode)
      I_Cathode="$2"
      shift
      shift
      ;;
    -ts | --timeStamp)
      DATETIME="$2"
      shift
      shift
      ;;
    -tr | --testRun)
      TEST="$2"
      shift
      shift
      ;;
    -h | --help)
    usage
    shift
    ;;
    *)
      echo "Invalid option: $1"
      usage
      
  esac
done

# Check for missing (NULL) inputs
if [ -z "$VC" ] || [ -z "$HV" ] || [ -z "$GAIN" ] || [ -z "$SERIAL" ] || [ -z "$DATETIME" ] || [ -z "$BASE" ] || [ -z "$I_Cathode" ] || [ -z "$TEST" ]; then
  echo "[ERROR] Missing required options"
  usage
fi

# Check for invalid inputs (non-numeric)
for u in $VC $HV $TIME $BASE $I_Cathode ; do
  if ! [[ "$u" =~ ^[0-9]+([.][0-9]+)?$ ]] ; then
    echo "[ERROR] Invalid value: $u"
    usage
  fi
done

if [ "$TEST" != "true" ] && [ "$TEST" != "false" ] ;then 
  echo "[ERROR] Invalid value for testRun: $TEST"
  echo "[Options]: true, false"
  usage
fi

if [ "$I_Cathode" != "7" ] && [ "$I_Cathode" != "9" ] && [ "$I_Cathode" != "12" ] && [ "$I_Cathode" != "15" ] && [ "$I_Cathode" != "18" ] ; then
  echo "[ERROR] Invalid value for cathode current: $I_Cathode"
  echo "[Options]: 7, 9, 12, 15, 18"
  usage
fi

if [ "$GAIN" != "20k" ] && [ "$GAIN" != "100k" ] && [ "$GAIN" != "200k" ] && [ "$GAIN" != "200k" ] ; then
  echo "[ERROR] Invalid value for preamp gain: $GAIN"
  echo "[Options]: 20k, 100k, 200k, 1M"
  usage
fi

if [ ${#SERIAL} -gt 8 ]; then
  echo "[ERROR] Invalid value for PMT serial: $SERIAL"
  echo "[Options]: XXX-XXX or XXX-XXXX"
  usage
fi

if [ "$BASE" != "3" ] && [ "$BASE" != "4" ] ; then
  echo "[ERROR]: Invalid value for number of stages in the base: $BASE"
  echo "[Options]: 3, 4"
  usage
fi

DATE=${DATETIME:0:8}
TIME=${DATETIME:8:12}

if [ ${#DATETIME} != 12 ] || [ ${DATE:0:4} -lt 2024 ] || [ ${DATE:4:2} -gt 12 ] || [ ${DATE:6:8} -gt 31 ] || [ $TIME -gt 2359 ] || [ ${TIME:0:2} -gt 23 ] || [ ${TIME:2:2} -gt 59 ]; then
  echo "[ERROR] Invalid value for PMT turned on time stamp: $DATETIME"
  usage
fi

echo "------------------------------------------------"
echo "|       Recording max anode current data       | "
echo "------------------------------------------------"
# Set LED voltages
STD_OUT="$(python Power_Supply_Control.py -v $VC 0)"
if [ $? -eq "1" ] ; then
  echo "[Recording Failed] Power supply failed!"
  exit 1
fi

echo "$STD_OUT"
IFS=', ' read -ra val <<< "$STD_OUT" # Separating string
I_PMT=${val[5]} # PMT base current
IC=${val[13]} # Constant LED current draw

if [[ -z "$DIR" ]];
then
  DIRNAME=./$base_dir/$SERIAL/`date +"%Y%m%d%H%M"`
else
  DIRNAME=./$base_dir/$DIR/$SERIAL/`date +"%Y%m%d%H%M"`
fi

for i in 12 9
  do
    echo ""
    echo "------------------------------------------------"
    echo "|  Starting a new record | Filter position $i   |"
    echo "------------------------------------------------"
    echo "[Wait]: Setting filter position: $i"
    python Filter_Control.py -c setPosition $i
    if [ $? -eq "1" ] ; then
      echo "[Recording Failed] Moving filter into position!"
      exit 1
    fi

    echo "[CMData] Running"
    ./CMData
    rm *.dat
    rm *.out

    echo "[CMData] Recording successful!"

    if [ "$directoryCreated" = false ] ; then
      echo "[Record Saving]: Creating data directory: $DIRNAME"
      mkdir -p $DIRNAME
      directoryCreated=true
    fi
    echo "[Record Saving]: Copying files to: $DIRNAME "
    mv ./Int_Run_000.root $DIRNAME/${filter_order[$i-1]}.root
    sleep 1
  done

echo "[Wait]: Setting filter position: 12"
python Filter_Control.py -c setPosition 12
if [ $? -eq "1" ] ; then
  echo "[Recording Failed] Moving filter into position!"
  exit 1
fi
cp ./CMDataSettings.txt $DIRNAME
echo "================================================"
echo "                  Record End                    "
echo "  Toral records:  2 filter positions           "
echo "  Data dir:       $DIRNAME                      "
echo "  Time escape:    $SECONDS seconds              "
echo "================================================"
echo ""
echo ""

echo "Filter_Order=4,11,8,2,9,7,3,5,1,6,10,12
Test_Run=$TEST
PMT_Power_On_Timestamp(DateTime)=$DATETIME
PMT_Current(mA)=$I_PMT
PMT_Base_Stages=$BASE
PMT_Serial=$SERIAL
Constant_LED(V)=$VC
Constant_LED(mA)=$IC
PMT_high_voltage(V)=$HV
Preamp_gain(Ohm)=$GAIN
Cathode_Current_at_max_brightness(nA)=$I_Cathode
Record_Time(s)=$SECONDS" >> $DIRNAME/Experiment_data.txt

python Read_Temp.py $DIRNAME

echo "------------------------------------------------"
echo "|      Calculating the max anode current       | "
echo "------------------------------------------------"
python Read_max_anode_current.py $DIRNAME
status=$?
if [ $status -eq "1" ] ; then
  echo "[ERROR]: Analysis failed"
  exit 1
elif [ $status -eq "2" ] ; then
  exit 2
elif [ $status -eq "3" ] ; then
  exit 3
fi
exit 0
