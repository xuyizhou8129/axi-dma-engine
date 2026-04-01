class descriptor:
    def __init__(self, start_address: int, burst_length: int, datasize: int):
        
        self.start_address = start_address # location in system memory

        self.burst_length = burst_length # burst length

        self.datasize = datasize # width of each data
    
    