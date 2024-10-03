# ABAP-Parallel-Processing
Parallel processing aid tool for ABAP. Imeplemented as a simple and fast way to create parallel processing implementations for large datasets, without having to take care of much of the boilerplate and cumberosme parts of this task. 

The concept is as simple as

Mandatory development for the parallel proessor part
1) Create a subclass of Abstract processor ZCL_CAUT_PARALLEL_PROCESSOR
2) Implement mandatory abstract methods 
  a)WORK: what you want to do with each data package
  b)GET_INPUT_TYPE: return a data reference to A TABLE type with the format you expect data packages in the WORK method
Optionally:
3) You can choose to have a diffrent type for output than for input, ie. output has enriched data fields form further calculations done in parallel, in such case you must redefine metod GET_OUTPUT_TYPE and return a TABLE type with the desired output

On the consumption part, you just need to instantiate your processor subclass, and call method process, passing the full dataset to be processed and indicating server group to use and size for package splits.
The control will return from the call to the PROCESS method only after all threads have finished their work and the returning parameter contain a data reference to a table type with all the results.
