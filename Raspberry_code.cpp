#include <opencv2/opencv.hpp>
#include <gpiod.h>
#include <iostream>
#include <unistd.h>

using namespace cv;
using namespace std;

// Pins (GPIO labels)
const unsigned int DATA_PINS[] = {17, 27, 22, 10, 9, 11, 5, 6};
const unsigned int PCLK_PIN    = 13;
const unsigned int VALID_PIN   = 19;

int main() {

    VideoCapture cap(0, CAP_V4L2);
    cap.set(CAP_PROP_FOURCC, VideoWriter::fourcc('M','J','P','G'));
    cap.set(CAP_PROP_FRAME_WIDTH, 640);
    cap.set(CAP_PROP_FRAME_HEIGHT, 480);

    if (!cap.isOpened()) {
        cerr << "Kamera acilamadi!" << endl;
        return -1;
    }

    struct gpiod_chip *chip = gpiod_chip_open("/dev/gpiochip4");
    struct gpiod_line_settings *settings = gpiod_line_settings_new();
    gpiod_line_settings_set_direction(settings, GPIOD_LINE_DIRECTION_OUTPUT);

    struct gpiod_line_config *line_cfg = gpiod_line_config_new();
    unsigned int all_pins[10];
    for(int i=0; i<8; i++) all_pins[i] = DATA_PINS[i];
    all_pins[8] = PCLK_PIN;
    all_pins[9] = VALID_PIN;
    gpiod_line_config_add_line_settings(line_cfg, all_pins, 10, settings);

    struct gpiod_request_config *req_cfg = gpiod_request_config_new();
    gpiod_request_config_set_consumer(req_cfg, "fast_cam_emre");
    struct gpiod_line_request *request = gpiod_chip_request_lines(chip, req_cfg, line_cfg);

    enum gpiod_line_value vals[8];

    Mat frame, small_frame, rgb_frame;
    cout << "Camera Active, starting...." << endl;

    while (true) {
        cap >> frame;
        if (frame.empty()) break;

        resize(frame, small_frame, Size(128, 128));
        cvtColor(small_frame, rgb_frame, COLOR_BGR2RGB);

        gpiod_line_request_set_value(request, VALID_PIN, GPIOD_LINE_VALUE_INACTIVE);
        gpiod_line_request_set_value(request, VALID_PIN, GPIOD_LINE_VALUE_ACTIVE);

        for (int y = 0; y < 128; y++) {
            uint8_t* row_ptr = rgb_frame.ptr<uint8_t>(y);
            for (int x = 0; x < 128 * 3; x++) {
                uint8_t byte_to_send = row_ptr[x];

                // Set up Bits
                for (int b = 0; b < 8; b++) {
                    vals[b] = (byte_to_send & (1 << b)) ? GPIOD_LINE_VALUE_ACTIVE : GPIOD_LINE_VALUE_INACTIVE;
                }

                gpiod_line_request_set_values_subset(request, 8, DATA_PINS, vals);
                gpiod_line_request_set_value(request, PCLK_PIN, GPIOD_LINE_VALUE_ACTIVE);
                gpiod_line_request_set_value(request, PCLK_PIN, GPIOD_LINE_VALUE_INACTIVE);
            }
        }
    }

    gpiod_line_request_release(request);
    gpiod_chip_close(chip);
    return 0;
}