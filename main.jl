using TSGs

config = Dict()
config["input_file"] = "data/wsj_22.mrg"
config["output_file_rules"] = "rules.txt"
config["output_file_instances"] = "instances.txt"
config["nepochs"] = 10
config["nosplit"] = ["_I"]

trainer = Trainer(config)
gibbs!(trainer)
output(trainer)
