using TSGs

config = Dict()
config["input_file"] = "data/wsj_22.mrg"
config["output_file"] = "out.txt"
config["nepochs"] = 10

trainer = Trainer(config)
gibbs!(trainer)
output(trainer)
