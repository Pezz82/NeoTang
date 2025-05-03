project -create neotang
set_device $env(DEVICE)
add_file neotang.json
run pnr
run pack
save
quit 