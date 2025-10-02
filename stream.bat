@echo off

ffmpeg -f dshow -i video="Insta360 Link" ^
       -c:v libx264 -preset ultrafast -tune zerolatency -b:v 5000k ^
       -c:a aac -b:a 128k ^
       -hls_time 10 -hls_list_size 6 -hls_flags delete_segments+temp_file ^
       ./hls/output.m3u8