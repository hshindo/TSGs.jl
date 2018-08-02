using TSGs

config = Dict()
config["input_file"] = "data/wsj_22.mrg"
config["output_file"] = "out.txt"
config["nepochs"] = 100
config["nosplit"] = ["_I"]

trainer = Trainer(config)
gibbs!(trainer)
output(trainer)
