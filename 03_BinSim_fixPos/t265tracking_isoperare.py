# First import the library
from pythonosc import osc_message_builder
from pythonosc import udp_client
import pyrealsense2 as rs
import math as m
import numpy as np
import msvcrt
import time

def start_tracker():
	# Declare RealSense pipeline, encapsulating the actual device and sensors
	pipe = rs.pipeline()

	# Build config object and request pose data
	cfg = rs.config()
	cfg.enable_stream(rs.stream.pose)

	# Start streaming with requested config
	pipe.start(cfg)

	# to show framerate:
	time_counter = 0
	time_average = 1
	start_time = time.time()  # start time of the loop

	# Offsets for OSC values
	pitch_osc_offset = 0

	# load information about Sources and Listener
	# pfad aus ander datei lesen
	with open("pyBinSimSetting_SourcesListenerDefs.txt", "r") as tf:
		values = tf.read().split(',')

	count = 0
	numChan = int(values[0])
	count += 1

	sourceOrientation = np.array([[0]*3]*numChan)
	sourcePosition = np.array([[0]*3]*numChan)
	listenerPosition = np.array([0]*3)
	values_yaw = np.array([0]*3)
	values_pitch = np.array([0] * 3)
	for idxC in range(0, numChan):
		for idxP in range(0, 3):
			sourcePosition[idxC][idxP] = int(values[count])
			count = count + 1
	for idxC in range(0, numChan):
		for idxP in range(0, 3):
			sourceOrientation[idxC][idxP] = int(values[count])
			count = count + 1
	for idxP in range(0, 3):
		listenerPosition[idxP] = int(values[count])
		count = count + 1
	for idxP in range(0, 3):
		values_yaw[idxP] = int(values[count])
		count = count + 1
	for idxP in range(0, 3):
		values_pitch[idxP] = int(values[count])
		count = count + 1

	sourceOrientation = sourceOrientation.tolist()
	sourcePosition = sourcePosition.tolist()
	listenerPosition = listenerPosition.tolist()
	values_yaw = values_yaw.tolist()
	values_pitch = values_pitch.tolist()

	print(sourcePosition)
	print(sourceOrientation)
	print(listenerPosition)
	print(values_yaw)
	print(values_pitch)

	availableAngles_yaw = range(values_yaw[0], values_yaw[1], values_yaw[2])  # Angle range and step size
	availableAngles_pitch = range(values_pitch[0], values_pitch[1], values_pitch[2])  # Angle range and step size
	availableAngles_roll = range(-180, 180, 5)

	availablePositions = range(0, 1, 1)  # Position range and step size

	# init
	last_data= []
	pitch_current = 0
	yaw_current = 0
	roll_current = 0

	x_current = 0
	y_current = 0
	z_current = 0

	pitch_offset = 0
	yaw_offset = 0
	roll_offset = 0

	x_offset = 0
	y_offset = 0
	z_offset = 0

	xPos_emu = 0;
	yPos_emu = 0;

	ds_on = 0;
	last_pose=[0,0,0]
	last_position=[0,0,0]
	i_now = 0;
	update = 1;



	# Create OSC client
	oscIdentifier = "/pyBinSim"
	ip = "127.0.0.1"
	ports = [10000, 10001, 10002, 10003]

	oscClient_ds = udp_client.SimpleUDPClient(ip, ports[0])
	oscClient_early = udp_client.SimpleUDPClient(ip, ports[1])
	oscClient_late = udp_client.SimpleUDPClient(ip, ports[2])
	oscClient_misc = udp_client.SimpleUDPClient(ip, ports[3])

	oscClient_misc.send_message("/pyBinSimLoudness", float(10))

	try:
		while 1:


			# Wait for the next set of frames from the camera
			frames = pipe.wait_for_frames()

			# Fetch pose frame
			pose = frames.get_pose_frame()
			if pose and pose!=last_pose:

				# Print some of the pose data to the terminal
				data = pose.get_pose_data()


				w = data.rotation.w
				x = -data.rotation.z
				y = data.rotation.x
				z = -data.rotation.y

				pitch = -m.asin(2.0 * (x * z - w * y)) * 180.0 / m.pi
				roll = m.atan2(2.0 * (w * x + y * z), w * w - x * x - y * y + z * z) * 180.0 / m.pi
				yaw = m.atan2(2.0 * (w * z + x * y), w * w + x * x - y * y - z * z) * 180.0 / m.pi

				# apply offset and shift values into interval [0; 360)
				#pitch_current = (pitch - pitch_offset - pitch_osc_offset) % 360
				#yaw_current   = (yaw   - yaw_offset)   % 360
				#roll_current  = (roll  - roll_offset)  % 360
				pitch_current = (pitch - pitch_offset - pitch_osc_offset)
				yaw_current   = (yaw   - yaw_offset)
				roll_current  = (roll  - roll_offset)
				x_current = data.translation.x - x_offset
				y_current = data.translation.y - y_offset
				z_current = data.translation.z - z_offset

				#data.translation.x, data.translation.y, data.translation.z
				#print("Position [m]: X: {0:.7f}, Y: {1:.7f}, Z: {2:.7f}".format(x_current, y_current, z_current))
				#print("RPY [deg]: Roll: {0:.7f}, Pitch: {1:.7f}, Yaw: {2:.7f}".format(roll_current, pitch_current, yaw_current))
				# print("Frame #{}".format(pose.frame_number))
				#print("Velocity: {}".format(data.velocity))
				#print("Acceleration: {}\n".format(data.acceleration))

				# Choose nearest available data
				yaw_out = min(availableAngles_yaw, key=lambda x: abs(x - yaw_current))
				pitch_out = min(availableAngles_pitch, key=lambda x: abs(x - pitch_current))
				roll_out = min(availableAngles_roll, key=lambda x: abs(x - roll_current))

				xPos = min(availablePositions, key=lambda x: abs(x - x_current))
				yPos = min(availablePositions, key=lambda x: abs(x - y_current))
				zPos = min(availablePositions, key=lambda x: abs(x - z_current))

				#param_zero=[0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0]
				numChan = 1;
				for i in range(0, numChan):
					# send data to switch early filter
					#binSimParameters = [channel, yaw, pitch, roll, xPos, yPos, zPos, 0, 0, 0]
					if last_pose!=[yaw_out,pitch_out,roll_out] or update==1:

						#binSimParameters_ds = [i, yaw_out, pitch_out, 0, xPos_emu, yPos_emu, 0, 0, 0, 0, 0, ds_on ,0,0,0,0]
						#binSimParameters_early = [i, yaw_out, pitch_out, 0, xPos_emu, yPos_emu, 0, 0, 0, 0, 0, 0 ,0,0,0,0]

						#binSimParameters_ds = [i, yaw_out, pitch_out, 0, listenerPosition[0], listenerPosition[1], listenerPosition[2], sourceOrientation[i][0], sourceOrientation[i][1], sourceOrientation[i][2],  sourcePosition[i][0], sourcePosition[i][1] ,sourcePosition[i][2],0,0,0]
						#binSimParameters_early = [i, yaw_out, pitch_out, 0, listenerPosition[0], listenerPosition[1], listenerPosition[2], sourceOrientation[i][0], sourceOrientation[i][1], sourceOrientation[i][2],  sourcePosition[i][0], sourcePosition[i][1] ,sourcePosition[i][2],0,0,0]

						binSimParameters_ds = [0, yaw_out, pitch_out, 0, listenerPosition[0], listenerPosition[1], listenerPosition[2], sourceOrientation[i_now][0], sourceOrientation[i_now][1], sourceOrientation[i_now][2],  sourcePosition[i_now][0], sourcePosition[i_now][1] ,sourcePosition[i_now][2],0,0,0]
						binSimParameters_early = [0, yaw_out, pitch_out, 0, listenerPosition[0], listenerPosition[1], listenerPosition[2], sourceOrientation[i_now][0], sourceOrientation[i_now][1], sourceOrientation[i_now][2],  sourcePosition[i_now][0], sourcePosition[i_now][1] ,sourcePosition[i_now][2],0,0,0]

						oscClient_ds.send_message("/pyBinSim_ds_Filter", binSimParameters_ds)
						oscClient_early.send_message("/pyBinSim_early_Filter", binSimParameters_early)
						print(binSimParameters_ds)

					#if last_position!=[xPos,yPos,zPos]:
					if update==1:
						# send data to switch late filter
						#binSimParameters = [i, yaw_out, pitch_out, 0, 0, 0, 0, sourceOrientation[i][0], sourceOrientation[i][1], sourceOrientation[i][2],  sourcePosition[i][0], sourcePosition[i][1] ,sourcePosition[i][2],0,0,0]
						binSimParameters_late = [0, 0, 0, 0, listenerPosition[0], listenerPosition[1], listenerPosition[2], sourceOrientation[i_now][0], sourceOrientation[i_now][1], sourceOrientation[i_now][2],  sourcePosition[i_now][0], sourcePosition[i_now][1] ,sourcePosition[i_now][2],0,0,0]

						oscClient_late.send_message("/pyBinSim_late_Filter", binSimParameters_late)
						#print(binSimParameters_late)
						update=0

				last_pose=[yaw_out,pitch_out,roll_out]
				last_position=[xPos,yPos,zPos]

				time_counter += 1
				if (time.time() - start_time) > time_average:
					print("FPS: ", time_counter / (time.time() - start_time))
					time_counter = 0
					start_time = time.time()

			if msvcrt.kbhit():
				char = msvcrt.getch()
				#print(ord(char))
				# Key 'n' sets zero pos and pose
				if ord(char) == 110:
					pitch_offset = pitch
					yaw_offset = yaw
					roll_offset = roll

					x_offset = data.translation.x
					y_offset = data.translation.y
					z_offset = data.translation.z

				if ord(char) == 49:
					print('source poster')
					i_now = 0
					update = 1
				if ord(char) == 50:
					print('source saeule')
					i_now =1
					update = 1


	except KeyboardInterrupt:
		pipe.stop()


if __name__ == "__main__":
	start_tracker()
