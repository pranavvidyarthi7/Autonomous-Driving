import matplotlib.pyplot as plt
import numpy as np
import skimage.transform as tf
import socket
import threading
import os
import time
import json


host = '192.168.1.6'
port = 5000

s = socket.socket()
s.bind((host, port))

s.listen()

print("Server Started.")
sock, addr = s.accept()
print("client connedted ip:<" + str(addr) + ">")

img_shape = [392, 803]

rsrc = [[43.45456230828867, 118.00743250075844],
        [104.5055617352614, 69.46865203761757],
        [114.86050156739812, 60.83953551083698],
        [129.74572757609468, 50.48459567870026],
        [132.98164627363735, 46.38576532847949],
        [301.0336906326895, 98.16046448916306],
        [238.25686790036065, 62.56535881619311],
        [227.2547443287154, 56.30924933427718],
        [209.13359962247614, 46.817221154818526],
        [203.9561297064078, 43.5813024572758]]
rdst = [[10.822125594094452, 1.42189132706374],
        [21.177065426231174, 1.5297552836484982],
        [25.275895776451954, 1.42189132706374],
        [36.062291434927694, 1.6376192402332563],
        [40.376849698318004, 1.42189132706374],
        [11.900765159942026, -2.1376192402332563],
        [22.25570499207874, -2.1376192402332563],
        [26.785991168638553, -2.029755283648498],
        [37.033067044190524, -2.029755283648498],
        [41.67121717733509, -2.029755283648498]]

tform3_img = tf.ProjectiveTransform()
tform3_img.estimate(np.array(rdst), np.array(rsrc))


def perspective_tform(x, y):
    p1, p2 = tform3_img((x, y))[0]
    return p2, p1


def calc_curvature(v_ego, angle_steers, angle_offset=0):
    deg_to_rad = np.pi/180.
    slip_fator = 0.0014
    steer_ratio = 15.3
    wheel_base = 2.67

    angle_steers_rad = (angle_steers - angle_offset) * deg_to_rad
    curvature = angle_steers_rad / \
        (steer_ratio * wheel_base * (1. + slip_fator * v_ego**2))
    return curvature


def calc_lookahead_offset(v_ego, angle_steers, d_lookahead, angle_offset=0):
    curvature = calc_curvature(v_ego, angle_steers, angle_offset)

    y_actual = d_lookahead * \
        np.tan(np.arcsin(np.clip(d_lookahead * curvature, -0.999, 0.999))/2.)
    return y_actual, curvature


def get_points(v_ego, angle, offset=300):

    path_x = np.arange(0., 50.1, 0.5)
    path_y, curvature = calc_lookahead_offset(v_ego, -angle, path_x)

    rows = []
    cols = []
    for x, y in zip(path_x, path_y):
        row, col = perspective_tform(x, y)
        if row >= 0 and row < img_shape[0] and col >= 0 and col < img_shape[1]:
            rows.append(int(row))
            cols.append(int(col+offset))

    return rows, cols


angles = np.arange(-45, 45, 0.5)

while True:
    for angle in angles:
        rows, cols = get_points(30, angle)
        str_ = json.dumps({'rows': rows, 'cols': cols})
        sock.send(str_.encode())
        data1 = sock.recv(1382400)
        print(data1.decode())
    for angle in angles[::-1]:
        rows, cols = get_points(30, angle)
        str_ = json.dumps({'rows': rows, 'cols': cols})
        sock.send(str_.encode())
        data2 = sock.recv(1382400)
        print("HELOOOO")
        print(data2)
