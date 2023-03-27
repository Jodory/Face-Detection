# This script has to be run from the docker container started by ./docker_openvino2tensorflow.sh

usage ()
{
        echo "Generate a blob from an ONNX model with a specified number of shaves and cmx (nb cmx = nb shaves)"
        echo
        echo "Usage: ${0} [-m model_onnx] [-s nb_shaves]"
        echo
        echo "model_onnx: ONNX file"
        echo "nb_shaves must be between 1 and 13 (default=4)"
}

while getopts ":hm:n:" opt; do
        case ${opt} in
                h )
                        usage
                        exit 0
                        ;;
                m )
                        model_onnx=$OPTARG
                        ;;
                n )
                        nb_shaves=$OPTARG
                        ;;
                : )
                        echo "Error: -$OPTARG requires an argument."
                        usage
                        exit 1
                        ;;
                \? )
                        echo "Invalid option: -$OPTARG"
                        usage
                        exit 1
                        ;;
        esac
done

if [ -z "$model_onnx" ]
then
       usage
       exit 1
fi

if [ ! -f $model_onnx ]
then
        echo "The model ${model_onnx} does not exist"
        exit 1
fi
model=$(basename -s .onnx ${model_onnx})

if [ -z "$nb_shaves" ]
then
	nb_shaves=4
fi
if [ $nb_shaves -lt 1 -o $nb_shaves -gt 13 ]
then
        echo "Invalid number of shaves !"
        usage
        exit 1
fi



model_xml="${model}.xml"
model_blob="${model}_sh${nb_shaves}.blob"

echo Model: $model_xml $model_blob
echo Shaves $nb_shaves

source /opt/intel/openvino_2021/bin/setupvars.sh

# python3 -m onnxsim ${model}.onnx ${model}.onnx 
# if [ $? -ne 0 ]
# then
#         exit 1
# fi

mkdir -p openvino
$INTEL_OPENVINO_DIR/deployment_tools/model_optimizer/mo_onnx.py \
                --input_model ${model_onnx} --data_type half --model_name openvino/$model 

# Patch the xml file
python3 patch_xml.py -f openvino/$model_xml

$INTEL_OPENVINO_DIR/deployment_tools/tools/compile_tool/compile_tool -d MYRIAD \
                -m openvino/$model_xml \
                -ip FP16 \
                -VPU_NUMBER_OF_SHAVES $nb_shaves \
                -VPU_NUMBER_OF_CMX_SLICES $nb_shaves \
                -o ../$model_blob



