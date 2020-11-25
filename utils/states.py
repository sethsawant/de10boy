import json

with open('Opcodes.json') as f:
  data = json.load(f)

# generate case statement body for string generation from opcodes for debugging and for comment generation

opcode_to_mnemonic_str = {}
for opcode in range(0,0x100):
    opcode_str = '0x%02X'%opcode
    op_info = data["unprefixed"][opcode_str]
    mnemonic_str = op_info['mnemonic']
    for operand_info in op_info['operands']:
        if operand_info['immediate']:
            mnemonic_str = mnemonic_str + " " + operand_info["name"]
        else:
            mnemonic_str = mnemonic_str + " (" + operand_info["name"] + ")"
    opcode_to_mnemonic_str['8\'h%02X'%opcode] = mnemonic_str
prefix_opcode_to_mnemonic_str = {}
for opcode in range(0,0x100):
    opcode_str = '0x%02X'%opcode
    op_info = data["cbprefixed"][opcode_str]
    mnemonic_str = op_info['mnemonic']
    for operand_info in op_info['operands']:
        if operand_info['immediate']:
            mnemonic_str = mnemonic_str + " " + operand_info["name"]
        else:
            mnemonic_str = mnemonic_str + " (" + operand_info["name"] + ")"
    prefix_opcode_to_mnemonic_str['8\'h%02X'%opcode] = mnemonic_str

# generate states for each op  
    
all_states = []
opcode_to_states = {}
prefixed_opcode_to_states = {}

for opcode in range(0x0,0x100):
    opcode_str = '0x%02X'%opcode
    op_info = data["unprefixed"][opcode_str]
    mnemonic_str = op_info['mnemonic']
    op_states = []
    
    num_states = int(op_info["cycles"][0]/4)
    base_state_name = mnemonic_str+"_{0}".format('%02X'%opcode)
    if num_states == 1:
        op_states += [base_state_name]
    else:
        for state_num in range(0,num_states):
            if state_num == num_states - 1:
                op_states += [base_state_name+"_"+str(state_num)]
            else:
                op_states += [base_state_name+"_"+str(state_num), "WAIT_"+base_state_name+"_"+str(state_num)]
        
    opcode_to_states['8\'h%02X'%opcode] = op_states
    all_states = all_states + op_states
    
for opcode in range(0x0,0x100):
    opcode_str = '0x%02X'%opcode
    op_info = data["cbprefixed"][opcode_str]
    mnemonic_str = op_info['mnemonic']
    op_states = []
    
    num_states = int(op_info["cycles"][0]/4)-1
    base_state_name = mnemonic_str+"_{0}".format('%02X'%opcode)
    if num_states == 1:
        op_states += [base_state_name]
    else:
        for state_num in range(0,num_states):
            if state_num == num_states - 1:
                op_states += [base_state_name+"_"+str(state_num)]
            else:
                op_states += [base_state_name+"_"+str(state_num), "WAIT_"+base_state_name+"_"+str(state_num)]

    prefixed_opcode_to_states['8\'h%02X'%opcode] = op_states
    all_states = all_states + op_states
    
# generate necessay SV code
    
print('///////////////////////////////////// State declaration ////////////////////////')
for state in all_states:
    print(state+',')

print('///////////////////////////////////// Next State Assignments ////////////////////////')

print("FETCH next state ==============================")
for opcode, states in opcode_to_states.items():
    print(opcode, ":", "Next_state =", states[0]+";")
    
print("PREFIX_CB next state ===================================")
for opcode, states in prefixed_opcode_to_states.items():
    print(opcode, ":", "Next_state =", states[0]+";")
    
print("all other next state ==============================")
for state_set in list(opcode_to_states.values()) + list(prefixed_opcode_to_states.values()):
    if len(state_set) == 1: # dont need to specify next state if op is a single state
        continue
    else: # assign next states for each state (except for last which defaults to fetch)
        for curr_state, next_state in zip(state_set[:-1],state_set[1:]):
            print(curr_state.ljust(16), ':', 'Next_state =', next_state+';')
print("default          : Next_state = FETCH;")

print('///////////////////////////////////// State control signal template ////////////////////////')
for opcode, states in opcode_to_states.items():
    comment = opcode_to_mnemonic_str[opcode].center(15)
    blank = " ".ljust(24)
    first_state_str = '/*'+comment+'*/     '+states[0] # add a comment that specifies the specific op for the first state
    print(first_state_str.ljust(40)+' : ;')
    for state in states[1:]:
        if state[:4] == "WAIT": # omit wait states by default, not usually needed to do anything
            continue
        state_str = blank+state
        print(state_str.ljust(40)+' : ;')
        
for opcode, states in prefixed_opcode_to_states.items():
    comment = prefix_opcode_to_mnemonic_str[opcode].center(15)
    blank = " ".ljust(24)
    first_state_str = '/*'+comment+'*/     '+states[0] # add a comment that specifies the specific op for the first state
    print(first_state_str.ljust(40)+' : ;')
    for state in states[1:]:
        if state[:4] == "WAIT": # omit wait states by default, not usually needed to do anything
            continue
        state_str = blank+state
        print(state_str.ljust(40)+' : ;')
                                        


