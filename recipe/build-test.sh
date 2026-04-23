#!/bin/bash
set -ex

DALI_TEST_ROOT="${PREFIX}/share/nvidia-dali-test"
mkdir -p "${DALI_TEST_ROOT}"

# Copy Python test files
mkdir -p "${DALI_TEST_ROOT}/dali/test"
cp -r "${SRC_DIR}/dali/test/python" "${DALI_TEST_ROOT}/dali/test/"

# Copy QA infrastructure
mkdir -p "${DALI_TEST_ROOT}/qa"
cp "${SRC_DIR}/qa/test_template.sh" "${DALI_TEST_ROOT}/qa/"
cp "${SRC_DIR}/qa/test_template_impl.sh" "${DALI_TEST_ROOT}/qa/"
cp "${SRC_DIR}/qa/setup_test_common.sh" "${DALI_TEST_ROOT}/qa/"
cp "${SRC_DIR}/qa/setup_dali_extra.sh" "${DALI_TEST_ROOT}/qa/"
cp "${SRC_DIR}/qa/setup_packages.py" "${DALI_TEST_ROOT}/qa/"
cp "${SRC_DIR}/qa/leak.sup" "${DALI_TEST_ROOT}/qa/"
cp "${SRC_DIR}/qa/address.sup" "${DALI_TEST_ROOT}/qa/"
cp -r "${SRC_DIR}/qa/nose_wrapper" "${DALI_TEST_ROOT}/qa/"

# Copy TL0 Python self-test suites
for d in TL0_python-self-test \
         TL0_python-self-test-core \
         TL0_python-self-test-readers-decoders \
         TL0_python-self-test-operators_1 \
         TL0_python-self-test-operators_2; do
    cp -r "${SRC_DIR}/qa/${d}" "${DALI_TEST_ROOT}/qa/"
done

# Copy DALI_EXTRA_VERSION for test data version tracking
cp "${SRC_DIR}/DALI_EXTRA_VERSION" "${DALI_TEST_ROOT}/"

# Install entry point script
mkdir -p "${PREFIX}/bin"
cp "${RECIPE_DIR}/run-dali-tests" "${PREFIX}/bin/run-dali-tests"
chmod +x "${PREFIX}/bin/run-dali-tests"
